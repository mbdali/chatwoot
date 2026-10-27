import { mount } from '@vue/test-utils';
import MessageReactions from '../MessageReactions.vue';

describe('MessageReactions', () => {
  const defaultReactions = [
    {
      emoji: '👍',
      actor_type: 'Contact',
      actor_id: 1,
      actor_name: 'Customer',
    },
    {
      emoji: '👍',
      actor_type: 'User',
      actor_id: 42,
      actor_name: 'Agent',
    },
    {
      emoji: '❤️',
      actor_type: 'Contact',
      actor_id: 1,
      actor_name: 'Customer',
    },
  ];

  it('renders nothing when reactions array is empty', () => {
    const wrapper = mount(MessageReactions, {
      props: {
        reactions: [],
      },
    });

    expect(wrapper.find('div').exists()).toBe(false);
  });

  it('groups reactions by emoji and displays counts', () => {
    const wrapper = mount(MessageReactions, {
      props: {
        reactions: defaultReactions,
        currentUserId: 42,
      },
    });

    const buttons = wrapper.findAll('button');
    expect(buttons).toHaveLength(2);

    // 👍 has 2 reactions
    expect(buttons[0].text()).toContain('👍');
    expect(buttons[0].text()).toContain('2');

    // ❤️ has 1 reaction
    expect(buttons[1].text()).toContain('❤️');
  });

  it('highlights the reaction pill when current user has reacted', () => {
    const wrapper = mount(MessageReactions, {
      props: {
        reactions: defaultReactions,
        currentUserId: 42,
      },
    });

    const buttons = wrapper.findAll('button');
    // 👍 contains user 42
    expect(buttons[0].classes()).toContain('text-n-brand');
    // ❤️ does not contain user 42
    expect(buttons[1].classes()).not.toContain('text-n-brand');
  });

  it('emits toggle with emoji when clicked', async () => {
    const wrapper = mount(MessageReactions, {
      props: {
        reactions: defaultReactions,
        currentUserId: 42,
        canReact: true,
      },
    });

    const buttons = wrapper.findAll('button');
    await buttons[0].trigger('click');

    expect(wrapper.emitted('toggle')).toBeTruthy();
    expect(wrapper.emitted('toggle')[0]).toEqual(['👍']);
  });

  it('does not emit toggle when canReact is false', async () => {
    const wrapper = mount(MessageReactions, {
      props: {
        reactions: defaultReactions,
        currentUserId: 42,
        canReact: false,
      },
    });

    const buttons = wrapper.findAll('button');
    await buttons[0].trigger('click');

    expect(wrapper.emitted('toggle')).toBeFalsy();
  });
});
