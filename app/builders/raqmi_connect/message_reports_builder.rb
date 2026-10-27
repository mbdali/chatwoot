# frozen_string_literal: true

class RaqmiConnect::MessageReportsBuilder
  include DateRangeHelper

  attr_reader :account, :params

  DEFAULT_GROUP_BY = 'day'
  PALETTE = %w[
    rgb(var(--blue-9)) rgb(var(--teal-9)) rgb(var(--amber-9)) rgb(var(--ruby-9))
    rgb(var(--iris-9)) rgb(var(--grass-9)) rgb(var(--plum-9)) rgb(var(--cyan-9))
  ].freeze

  STATUS_CONFIGS = [
    { key: 'read', label: 'Read', color: 'rgb(var(--grass-9))' },
    { key: 'delivered', label: 'Delivered', color: 'rgb(var(--teal-9))' },
    { key: 'sent', label: 'Sent', color: 'rgb(var(--blue-9))' },
    { key: 'failed', label: 'Failed', color: 'rgb(var(--ruby-9))' }
  ].freeze

  def initialize(account, params)
    @account = account
    @params = params
    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]&.name || 'UTC'
  end

  def build
    { incoming: incoming_report, outgoing: outgoing_report }
  end

  private

  def period
    group = params[:group_by].to_s.downcase
    %w[day week month year hour].include?(group) ? group : DEFAULT_GROUP_BY
  end

  def current_range
    @current_range ||= range || default_range
  end

  def previous_range
    @previous_range ||= begin
      since_time = current_range.begin
      until_time = current_range.end
      duration = until_time.to_i - since_time.to_i
      (since_time - duration.seconds)...since_time
    end
  end

  def default_range
    30.days.ago.in_time_zone(@timezone)...Time.current.in_time_zone(@timezone)
  end

  def base_messages
    scope = account.messages.unscope(:order)
    scope = scope.where(inbox_id: params[:inbox_id]) if params[:inbox_id].present?
    scope
  end

  def calculate_trend(current_val, previous_val)
    return 0.0 if previous_val.to_f.zero?

    (((current_val.to_f - previous_val.to_f) / previous_val.to_f) * 100).round(2)
  end

  def format_date(date)
    case period
    when 'hour' then date.strftime('%H:%M')
    when 'month' then date.strftime('%b %Y')
    when 'year' then date.strftime('%Y')
    else date.strftime('%d %b')
    end
  end

  def incoming_report
    current_incoming = base_messages.where(message_type: :incoming, created_at: current_range)
    prev_incoming = base_messages.where(message_type: :incoming, created_at: previous_range)
    total = current_incoming.count
    prev_total = prev_incoming.count

    {
      total: total,
      previous_total: prev_total,
      trend: calculate_trend(total, prev_total),
      chart_data: build_inbox_timeseries(current_incoming, 'Incoming Messages', 'rgb(var(--blue-9))')
    }
  end

  def outgoing_report
    current_outgoing = base_messages.where(message_type: [:outgoing, :template], created_at: current_range)
    prev_outgoing = base_messages.where(message_type: [:outgoing, :template], created_at: previous_range)
    total = current_outgoing.count
    prev_total = prev_outgoing.count

    {
      total: total,
      previous_total: prev_total,
      trend: calculate_trend(total, prev_total),
      chart_data: build_outgoing_timeseries(current_outgoing)
    }.merge(calculate_delivery_stats(current_outgoing, prev_outgoing, total, prev_total))
  end

  def calculate_delivery_stats(current_scope, prev_scope, total, prev_total)
    curr = rates_for_scope(current_scope, total)
    prev = rates_for_scope(prev_scope, prev_total)

    {
      delivered_count: curr[:delivered],
      delivery_rate: curr[:delivery_rate],
      previous_delivery_rate: prev[:delivery_rate],
      delivery_rate_trend: (curr[:delivery_rate] - prev[:delivery_rate]).round(2),
      failed_count: curr[:failed],
      error_rate: curr[:error_rate],
      previous_error_rate: prev[:error_rate],
      error_rate_trend: (curr[:error_rate] - prev[:error_rate]).round(2)
    }
  end

  def rates_for_scope(scope, total)
    counts = scope.group(:status).count
    delivered = counts['delivered'].to_i + counts['read'].to_i
    failed = counts['failed'].to_i
    {
      delivered: delivered,
      failed: failed,
      delivery_rate: total.positive? ? ((delivered.to_f / total) * 100).round(2) : 0.0,
      error_rate: total.positive? ? ((failed.to_f / total) * 100).round(2) : 0.0
    }
  end

  def build_outgoing_timeseries(scope)
    group_mode = params[:outgoing_group_by].to_s.presence || (params[:inbox_id].present? ? 'status' : 'inbox')
    if group_mode == 'status'
      build_outgoing_status_timeseries(scope)
    else
      build_inbox_timeseries(scope, 'Outgoing Messages', 'rgb(var(--teal-9))')
    end
  end

  def build_outgoing_status_timeseries(scope)
    grouped = scope.group_by_period(period, :created_at, range: current_range, time_zone: @timezone, default_value: 0)
                   .group(:status)
                   .count
    dates = grouped.keys.map(&:first).uniq.sort
    series = STATUS_CONFIGS.map do |cfg|
      { id: "status_#{cfg[:key]}", label: cfg[:label], color: cfg[:color], data: dates.map { |d| grouped[[d, cfg[:key]]] || 0 } }
    end

    { categories: dates.map { |d| format_date(d) }, series: series }
  end

  def build_inbox_timeseries(scope, fallback_label, fallback_color)
    if params[:inbox_id].present?
      build_single_inbox_timeseries(scope, fallback_label, fallback_color)
    else
      build_multi_inbox_timeseries(scope, fallback_label, fallback_color)
    end
  end

  def build_single_inbox_timeseries(scope, fallback_label, fallback_color)
    inbox = account.inboxes.find_by(id: params[:inbox_id])
    counts = scope.group_by_period(period, :created_at, range: current_range, time_zone: @timezone, default_value: 0).count

    {
      categories: counts.keys.map { |d| format_date(d) },
      series: [{
        id: "inbox_#{params[:inbox_id]}",
        label: inbox&.name || fallback_label,
        color: fallback_color,
        data: counts.values
      }]
    }
  end

  def build_multi_inbox_timeseries(scope, fallback_label, fallback_color)
    grouped = scope.group_by_period(period, :created_at, range: current_range, time_zone: @timezone, default_value: 0)
                   .group(:inbox_id)
                   .count
    dates = grouped.keys.map(&:first).uniq.sort
    inbox_ids = grouped.keys.filter_map(&:last).uniq
    inbox_map = account.inboxes.where(id: inbox_ids).index_by(&:id)

    series = build_inbox_series_list(inbox_ids, inbox_map, dates, grouped)
    return fallback_empty_series(scope, fallback_label, fallback_color) if series.empty?

    { categories: dates.map { |d| format_date(d) }, series: series }
  end

  def fallback_empty_series(scope, fallback_label, fallback_color)
    counts = scope.group_by_period(period, :created_at, range: current_range, time_zone: @timezone, default_value: 0).count
    {
      categories: counts.keys.map { |d| format_date(d) },
      series: [{ id: 'inbox_empty', label: fallback_label, color: fallback_color, data: counts.values }]
    }
  end

  def build_inbox_series_list(inbox_ids, inbox_map, dates, grouped)
    inbox_ids.each_with_index.map do |inbox_id, idx|
      inbox_record = inbox_map[inbox_id]
      {
        id: "inbox_#{inbox_id}",
        label: inbox_record&.name || "Inbox #{inbox_id}",
        color: PALETTE[idx % PALETTE.length],
        data: dates.map { |d| grouped[[d, inbox_id]] || 0 }
      }
    end
  end
end
