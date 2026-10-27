import { mount } from '@vue/test-utils';
import QuickReactionPicker from '../QuickReactionPicker.vue';

describe('QuickReactionPicker', () => {
  it('renders all quick emojis', () => {
    const wrapper = mount(QuickReactionPicker, {
      global: {
        directives: {
          'on-click-outside': {},
        },
      },
    });

    const buttons = wrapper.findAll('button');
    expect(buttons).toHaveLength(6);
    expect(buttons[0].text()).toBe('👍');
    expect(buttons[1].text()).toBe('❤️');
  });

  it('emits select when an emoji is clicked', async () => {
    const wrapper = mount(QuickReactionPicker, {
      global: {
        directives: {
          'on-click-outside': {},
        },
      },
    });

    const buttons = wrapper.findAll('button');
    await buttons[0].trigger('click');

    expect(wrapper.emitted('select')).toBeTruthy();
    expect(wrapper.emitted('select')[0]).toEqual(['👍']);
  });

  it('highlights the active emoji if provided', () => {
    const wrapper = mount(QuickReactionPicker, {
      props: {
        activeEmoji: '❤️',
      },
      global: {
        directives: {
          'on-click-outside': {},
        },
      },
    });

    const buttons = wrapper.findAll('button');
    expect(buttons[1].classes()).toContain('ring-1');
  });
});
