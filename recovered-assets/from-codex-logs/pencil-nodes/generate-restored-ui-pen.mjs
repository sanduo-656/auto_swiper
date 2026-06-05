import { writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const outFile = join(
  dirname(fileURLToPath(import.meta.url)),
  'auto-swiper-current-ui-restored.pen',
);

const c = {
  canvas: '#F4F5F7',
  surface: '#FAFAFB',
  strong: '#FFFFFF',
  mutedSurface: '#F6F7F9',
  border: '#D7DDE8',
  strongBorder: '#C7D0DE',
  text: '#171821',
  muted: '#687083',
  faint: '#8D96A8',
  primary: '#405AA8',
  primaryTint: '#EEF2FF',
  success: '#2F5E4E',
  successTint: '#EAF3EF',
  warning: '#A14A22',
  warningTint: '#FFF6ED',
  warningBorder: '#EAD5C8',
  dark: '#263238',
};

let seq = 0;
function nextId(name) {
  const clean = name.replace(/[^a-zA-Z0-9]+/g, '_').replace(/^_+|_+$/g, '');
  return `${clean || 'node'}_${++seq}`;
}

function node(type, name, props = {}, children = []) {
  const result = { id: nextId(name), name, type, ...props };
  if (children.length) result.children = children;
  return result;
}

function frame(name, props = {}, children = []) {
  return node('frame', name, props, children);
}

function rect(name, props = {}) {
  return node('rectangle', name, props);
}

function text(name, content, props = {}) {
  return node('text', name, {
    content,
    fontFamily: 'Inter',
    fill: c.text,
    ...props,
  });
}

function stroke(color = c.border, thickness = 1) {
  return { fill: color, thickness };
}

function centeredTextButton(name, label, props = {}) {
  return frame(name, {
    fill: props.fill ?? c.strong,
    cornerRadius: props.radius ?? 8,
    stroke: stroke(props.border ?? c.strongBorder),
    layout: 'horizontal',
    justifyContent: 'center',
    alignItems: 'center',
    ...props.box,
  }, [
    text(`${name}/label`, label, {
      fontSize: props.fontSize ?? 13,
      fontWeight: props.weight ?? '900',
      fill: props.color ?? c.text,
    }),
  ]);
}

function switchNode(name, on, props = {}) {
  return frame(name, {
    width: 48,
    height: 26,
    fill: on ? c.success : '#DDE2EA',
    cornerRadius: 13,
    layout: 'none',
    ...props,
  }, [
    frame(`${name}/knob`, {
      x: on ? 26 : 4,
      y: 4,
      width: 18,
      height: 18,
      fill: c.strong,
      cornerRadius: 9,
    }),
  ]);
}

function valueStepper(name, label, value, unit, y, muted = false) {
  const ink = muted ? c.faint : c.text;
  const inputFill = muted ? c.mutedSurface : c.surface;
  return [
    text(`${name}/label`, label, {
      x: 20,
      y: y + 12,
      fontSize: 13,
      fontWeight: '700',
      fill: c.text,
    }),
    centeredTextButton(`${name}/minus`, '−', {
      box: { x: 132, y, width: 34, height: 34 },
      border: c.border,
      color: muted ? c.faint : c.muted,
      fontSize: 18,
    }),
    frame(`${name}/value_input`, {
      x: 176,
      y,
      width: 96,
      height: 34,
      fill: inputFill,
      cornerRadius: 8,
      stroke: stroke(muted ? c.border : c.strongBorder),
      layout: 'horizontal',
      gap: 4,
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text(`${name}/value`, value, {
        fontSize: 14,
        fontWeight: '900',
        fill: ink,
      }),
      text(`${name}/unit`, unit, {
        fontSize: 11,
        fontWeight: '800',
        fill: muted ? c.faint : c.muted,
      }),
    ]),
    centeredTextButton(`${name}/plus`, '+', {
      box: { x: 282, y, width: 34, height: 34 },
      border: c.border,
      color: muted ? c.faint : c.muted,
      fontSize: 17,
    }),
  ];
}

function phoneHeader() {
  return frame('phone/header', {
    x: 16,
    y: 16,
    width: 398,
    height: 56,
    layout: 'horizontal',
    gap: 10,
    alignItems: 'center',
  }, [
    text('phone/header/title', '随机滑屏', {
      fontSize: 20,
      fontWeight: '800',
    }),
    frame('phone/header/version_badge', {
      width: 62,
      height: 20,
      fill: c.mutedSurface,
      cornerRadius: 10,
      stroke: stroke(c.strongBorder),
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('phone/header/version_text', 'v0.0.2', {
        fontSize: 11,
        fontWeight: '900',
        fill: c.muted,
      }),
    ]),
    frame('phone/header/spacer', { width: 'fill_container', height: 1 }),
    frame('phone/header/collapse_button', {
      width: 44,
      height: 34,
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('phone/header/collapse_text', '收起', {
        fontSize: 12,
        fontWeight: '800',
        fill: c.muted,
      }),
    ]),
    frame('phone/header/refresh_button', {
      width: 44,
      height: 34,
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('phone/header/refresh_text', '刷新', {
        fontSize: 12,
        fontWeight: '800',
        fill: c.muted,
      }),
    ]),
  ]);
}

function phoneStatus() {
  return frame('phone/status_panel', {
    x: 16,
    y: 88,
    width: 398,
    height: 76,
    fill: c.warningTint,
    cornerRadius: 8,
    stroke: stroke(c.warningBorder),
    layout: 'none',
  }, [
    frame('phone/status/warning_icon', {
      x: 20,
      y: 25,
      width: 18,
      height: 18,
      fill: c.warning,
      cornerRadius: 9,
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('phone/status/warning_mark', '!', {
        fontSize: 13,
        fontWeight: '900',
        fill: c.strong,
      }),
    ]),
    text('phone/status/title', '无障碍未开启', {
      x: 50,
      y: 18,
      fontSize: 14,
      fontWeight: '700',
    }),
    text('phone/status/desc', '开启后才能在其他 App 中执行滑动、点击和连击。', {
      x: 50,
      y: 42,
      width: 242,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.muted,
    }),
    centeredTextButton('phone/status/settings_button', '设置', {
      box: { x: 318, y: 21, width: 64, height: 34 },
      fontSize: 12,
    }),
  ]);
}

function phoneRun() {
  return frame('phone/run_card', {
    x: 16,
    y: 180,
    width: 398,
    height: 120,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/run/title', '运行', {
      x: 20,
      y: 20,
      fontSize: 16,
      fontWeight: '700',
    }),
    text('phone/run/subtitle', '启动后按“去向”进入目标应用', {
      x: 70,
      y: 21,
      width: 220,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.faint,
    }),
    centeredTextButton('phone/run/start_disabled', '启动', {
      box: { x: 20, y: 62, width: 172, height: 42 },
      fill: c.mutedSurface,
      border: c.border,
      color: c.faint,
    }),
    centeredTextButton('phone/run/stop_disabled', '停止', {
      box: { x: 206, y: 62, width: 172, height: 42 },
      fill: c.mutedSurface,
      border: c.border,
      color: c.faint,
    }),
  ]);
}

function segmented(name, x, y, width, height, labels, selectedIndex, selectedFill = c.primaryTint, selectedColor = c.text) {
  return frame(name, {
    x,
    y,
    width,
    height,
    fill: c.strong,
    cornerRadius: height / 2,
    stroke: stroke(c.strongBorder),
    layout: 'horizontal',
  }, labels.map((label, i) => frame(`${name}/${label}${i === selectedIndex ? '_selected' : ''}`, {
    width: i === labels.length - 1 ? 'fill_container' : Math.round(width / labels.length),
    height: 'fill_container',
    fill: i === selectedIndex ? selectedFill : undefined,
    cornerRadius: i === 0 ? [height / 2, 0, 0, height / 2] : i === labels.length - 1 ? [0, height / 2, height / 2, 0] : undefined,
    layout: 'horizontal',
    justifyContent: 'center',
    alignItems: 'center',
  }, [
    text(`${name}/${label}/text`, label, {
      fontSize: 13,
      fontWeight: '800',
      fill: i === selectedIndex ? selectedColor : c.text,
    }),
  ])));
}

function phoneDestination() {
  return frame('phone/destination_card', {
    x: 16,
    y: 316,
    width: 398,
    height: 154,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/destination/title', '启动后去向', {
      x: 20,
      y: 18,
      fontSize: 16,
      fontWeight: '700',
    }),
    text('phone/destination/subtitle', '决定主界面收起后回到哪里。', {
      x: 112,
      y: 20,
      width: 190,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.faint,
    }),
    segmented('phone/destination/segmented_control', 20, 54, 202, 36, ['上一个', '指定 App'], 0),
    frame('phone/destination/target_app_row', {
      x: 20,
      y: 104,
      width: 358,
      height: 30,
      fill: c.mutedSurface,
      cornerRadius: 8,
      stroke: stroke(c.border),
      layout: 'horizontal',
      gap: 8,
      alignItems: 'center',
      padding: [0, 4, 0, 14],
    }, [
      text('phone/destination/target_label', '目标 App：未指定', {
        fontSize: 12,
        fontWeight: '600',
        fill: c.muted,
      }),
      frame('phone/destination/target_spacer', { width: 'fill_container', height: 1 }),
      text('phone/destination/pick_text', '选择', {
        fontSize: 11,
        fontWeight: '700',
      }),
      text('phone/destination/refresh_text', '刷新', {
        fontSize: 11,
        fontWeight: '700',
        fill: c.muted,
      }),
    ]),
    text('phone/destination/desc', '指定 App 只在“去向”里选择，标靶只负责位置校准。', {
      x: 20,
      y: 138,
      width: 340,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.muted,
    }),
  ]);
}

function phoneAssist() {
  return frame('phone/assist_card', {
    x: 16,
    y: 486,
    width: 398,
    height: 168,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/assist/title', '运行辅助', { x: 20, y: 18, fontSize: 16, fontWeight: '700' }),
    text('phone/assist/overlay_label', '小窗口', { x: 20, y: 58, fontSize: 13, fontWeight: '700' }),
    text('phone/assist/overlay_desc', '暂停 / 停止 / 收起', {
      x: 92,
      y: 59,
      width: 170,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.muted,
    }),
    switchNode('phone/assist/overlay_switch_on', true, { x: 318, y: 50 }),
    text('phone/assist/anchor_label', '点击标靶', { x: 20, y: 104, fontSize: 13, fontWeight: '700' }),
    text('phone/assist/anchor_desc', '校准点击点和滑动起止点', {
      x: 92,
      y: 105,
      width: 154,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.muted,
    }),
    frame('phone/assist/target_preview', {
      x: 342,
      y: 94,
      width: 42,
      height: 42,
      fill: '#F1F7FF',
      cornerRadius: 21,
      stroke: stroke('#C9D8F4'),
      layout: 'none',
    }, [
      rect('phone/assist/target_h', { x: 7, y: 20, width: 28, height: 2, fill: c.primary, cornerRadius: 1 }),
      rect('phone/assist/target_v', { x: 20, y: 7, width: 2, height: 28, fill: c.primary, cornerRadius: 1 }),
    ]),
    frame('phone/assist/coordinate_chip', {
      x: 204,
      y: 137,
      width: 112,
      height: 22,
      fill: c.mutedSurface,
      cornerRadius: 11,
      stroke: stroke(c.border),
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('phone/assist/coordinate_text', '未校准', { fontSize: 11, fontWeight: '900', fill: '#3B4B69' }),
    ]),
    centeredTextButton('phone/assist/show_target_button', '显示标靶', {
      box: { x: 20, y: 128, width: 96, height: 30 },
      fontSize: 11,
    }),
    centeredTextButton('phone/assist/hide_target_button', '隐藏', {
      box: { x: 126, y: 128, width: 64, height: 30 },
      border: c.border,
      color: c.faint,
      fontSize: 11,
    }),
  ]);
}

function phoneAction() {
  return frame('phone/action_card', {
    x: 16,
    y: 670,
    width: 398,
    height: 202,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/action/title', '动作', { x: 20, y: 18, fontSize: 16, fontWeight: '700' }),
    text('phone/action/subtitle', '选择动作类型，运行后锁定。', {
      x: 66,
      y: 20,
      width: 190,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.faint,
    }),
    segmented('phone/action/segmented_control', 20, 56, 302, 40, ['滑动', '点击', '连击'], 0),
    frame('phone/action/description_box', {
      x: 20,
      y: 112,
      width: 358,
      height: 38,
      fill: c.mutedSurface,
      cornerRadius: 8,
      stroke: stroke(c.border),
      layout: 'horizontal',
      alignItems: 'center',
      padding: [0, 14],
    }, [
      text('phone/action/description_text', '点住后快速划一下，适合短视频连续滚动。', {
        width: 'fill_container',
        textGrowth: 'fixed-width',
        fontSize: 11,
        fontWeight: '500',
        lineHeight: 1.25,
        fill: c.muted,
      }),
    ]),
    text('phone/action/direction_label', '方向', { x: 20, y: 170, fontSize: 13, fontWeight: '700' }),
    text('phone/action/direction_value', '向上', { x: 92, y: 170, fontSize: 13, fontWeight: '700', fill: c.success }),
  ]);
}

function phoneInterval() {
  return frame('phone/interval_card', {
    x: 16,
    y: 888,
    width: 398,
    height: 246,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/interval/title', '间隔', { x: 20, y: 20, fontSize: 16, fontWeight: '700' }),
    text('phone/interval/subtitle', '可点数值输入，步进 0.1 秒。滑条只反馈当前范围。', {
      x: 68,
      y: 20,
      width: 288,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.faint,
    }),
    ...valueStepper('phone/interval/min', '最小间隔', '3.0', '秒', 56),
    ...valueStepper('phone/interval/max', '最大间隔', '8.0', '秒', 110),
    rect('phone/interval/range_bg', { x: 32, y: 168, width: 334, height: 5, fill: '#E3E7EF', cornerRadius: 3 }),
    rect('phone/interval/range_fill', { x: 44, y: 168, width: 34, height: 5, fill: c.primary, cornerRadius: 3 }),
    frame('phone/interval/range_start_thumb', { x: 43, y: 160, width: 20, height: 20, fill: c.primary, cornerRadius: 10 }),
    frame('phone/interval/range_end_thumb', { x: 78, y: 160, width: 20, height: 20, fill: c.primary, cornerRadius: 10 }),
    segmented('phone/interval/preset_group', 20, 196, 332, 32, ['快', '像真人', '慢', '自定义'], 1),
  ]);
}

function phoneMultiTap() {
  return frame('phone/multi_tap_card', {
    x: 16,
    y: 1150,
    width: 398,
    height: 166,
    fill: c.surface,
    cornerRadius: 8,
    stroke: stroke(c.border),
    opacity: 0.9,
    layout: 'none',
  }, [
    text('phone/multi_tap/title', '连击参数', { x: 20, y: 20, fontSize: 16, fontWeight: '700' }),
    text('phone/multi_tap/subtitle', '仅在“连击”模式生效', {
      x: 104,
      y: 21,
      width: 160,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.faint,
    }),
    ...valueStepper('phone/multi_tap/count', '次数', '3', '次', 56, true),
    ...valueStepper('phone/multi_tap/interval', '连击间隔', '100', 'ms', 110, true),
  ]);
}

function phoneRandom() {
  return frame('phone/random_card', {
    x: 16,
    y: 1332,
    width: 398,
    height: 158,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/random/title', '随机与落点', { x: 20, y: 20, fontSize: 16, fontWeight: '700' }),
    text('phone/random/strength_label', '随机强度', { x: 20, y: 64, fontSize: 13, fontWeight: '700' }),
    text('phone/random/strength_value', '像真人', { x: 316, y: 64, fontSize: 13, fontWeight: '900', fill: c.success }),
    rect('phone/random/strength_track_bg', { x: 20, y: 94, width: 358, height: 5, fill: '#E3E7EF', cornerRadius: 3 }),
    rect('phone/random/strength_track_fill', { x: 20, y: 94, width: 232, height: 5, fill: c.primary, cornerRadius: 3 }),
    frame('phone/random/strength_thumb', { x: 242, y: 86, width: 20, height: 20, fill: c.primary, cornerRadius: 10 }),
    text('phone/random/scatter_label', '散点半径', { x: 20, y: 122, fontSize: 13, fontWeight: '700' }),
    text('phone/random/scatter_value', '10 px', { x: 326, y: 122, fontSize: 13, fontWeight: '900', fill: c.primary }),
    rect('phone/random/scatter_track_bg', { x: 110, y: 129, width: 180, height: 5, fill: '#E3E7EF', cornerRadius: 3 }),
    rect('phone/random/scatter_track_fill', { x: 110, y: 129, width: 36, height: 5, fill: c.primary, cornerRadius: 3 }),
    frame('phone/random/scatter_thumb', { x: 136, y: 121, width: 20, height: 20, fill: c.primary, cornerRadius: 10 }),
  ]);
}

function phoneDebug() {
  return frame('phone/debug_log_card', {
    x: 16,
    y: 1506,
    width: 398,
    height: 164,
    fill: c.strong,
    cornerRadius: 8,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('phone/debug/title', '调试日志', { x: 20, y: 20, fontSize: 16, fontWeight: '700' }),
    text('phone/debug/switch_label', '手动开启', { x: 116, y: 23, fontSize: 11, fontWeight: '900', fill: c.muted }),
    switchNode('phone/debug/switch_off', false, { x: 190, y: 16, fill: '#E3E7EF' }),
    frame('phone/debug/state_badge', {
      x: 252,
      y: 18,
      width: 66,
      height: 22,
      fill: c.mutedSurface,
      cornerRadius: 11,
      stroke: stroke(c.border),
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('phone/debug/state_text', '默认关闭', { fontSize: 10, fontWeight: '900', fill: c.muted }),
    ]),
    frame('phone/debug/path_box', {
      x: 20,
      y: 58,
      width: 358,
      height: 40,
      fill: c.mutedSurface,
      cornerRadius: 8,
      stroke: stroke(c.border),
      layout: 'horizontal',
      alignItems: 'center',
      padding: [0, 12],
    }, [
      text('phone/debug/path_text', '日志路径读取中...', {
        width: 'fill_container',
        textGrowth: 'fixed-width',
        fontSize: 11,
        fontWeight: '600',
        lineHeight: 1.2,
        fill: c.muted,
      }),
    ]),
    text('phone/debug/desc', '关闭时不写入日志，避免长期运行生成大文件。', {
      x: 20,
      y: 110,
      width: 234,
      textGrowth: 'fixed-width',
      fontSize: 11,
      fontWeight: '500',
      lineHeight: 1.25,
      fill: c.muted,
    }),
    centeredTextButton('phone/debug/clear_button', '清空', {
      box: { x: 266, y: 112, width: 52, height: 34 },
      border: c.border,
      fontSize: 11,
    }),
    centeredTextButton('phone/debug/copy_button', '复制', {
      box: { x: 326, y: 112, width: 52, height: 34 },
      border: c.border,
      fontSize: 11,
    }),
  ]);
}

function phone() {
  return frame('layout / 移动端', {
    x: 0,
    y: 0,
    width: 430,
    height: 1710,
    fill: c.canvas,
    cornerRadius: 0,
    stroke: stroke(c.strongBorder),
    layout: 'none',
    clip: true,
  }, [
    phoneHeader(),
    phoneStatus(),
    phoneRun(),
    phoneDestination(),
    phoneAssist(),
    phoneAction(),
    phoneInterval(),
    phoneMultiTap(),
    phoneRandom(),
    phoneDebug(),
  ]);
}

function padTopBar() {
  return frame('pad/top_bar', {
    x: 0,
    y: 0,
    width: 1366,
    height: 72,
    fill: c.strong,
    stroke: stroke(c.border),
    layout: 'none',
  }, [
    text('pad/top_bar/title', '随机滑屏', { x: 28, y: 22, fontSize: 22, fontWeight: '900', lineHeight: 1 }),
    frame('pad/top_bar/version_badge', {
      x: 129,
      y: 15,
      width: 78,
      height: 28,
      fill: c.mutedSurface,
      cornerRadius: 14,
      stroke: stroke(c.strongBorder),
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('pad/top_bar/version_text', 'v0.0.2', { fontSize: 13, fontWeight: '900', fill: c.muted }),
    ]),
    frame('pad/top_bar/status_dot', { x: 806, y: 31, width: 10, height: 10, fill: c.warning, cornerRadius: 5 }),
    text('pad/top_bar/status_text', '无障碍未开启', { x: 824, y: 29, fontSize: 14, fontWeight: '900', lineHeight: 1, fill: c.warning }),
    frame('pad/top_bar/status_badge', {
      x: 928,
      y: 23,
      width: 62,
      height: 22,
      fill: c.warningTint,
      cornerRadius: 11,
      stroke: stroke(c.warningBorder),
      layout: 'horizontal',
      justifyContent: 'center',
      alignItems: 'center',
    }, [
      text('pad/top_bar/status_badge_text', '待授权', { fontSize: 10, fontWeight: '900', fill: c.warning }),
    ]),
    centeredTextButton('pad/top_bar/settings_button', '打开设置', { box: { x: 1052, y: 18, width: 96, height: 36 } }),
    centeredTextButton('pad/top_bar/start_disabled', '启动', {
      box: { x: 1160, y: 18, width: 78, height: 36 },
      fill: c.mutedSurface,
      border: c.border,
      color: c.faint,
    }),
    centeredTextButton('pad/top_bar/stop_disabled', '停止', {
      box: { x: 1250, y: 18, width: 72, height: 36 },
      fill: c.mutedSurface,
      border: c.border,
      color: c.faint,
    }),
  ]);
}

function padPanel(name, title, x, y, width, height, children) {
  return frame(name, {
    x,
    y,
    width,
    height,
    fill: c.strong,
    cornerRadius: 10,
    stroke: stroke('#E0E3E8'),
    layout: 'none',
  }, [
    text(`${name}/title`, title, { x: title === '运行' ? 24 : 28, y: 28, fontSize: 20, fontWeight: '900', lineHeight: 1 }),
    ...children,
  ]);
}

function padRunPanel() {
  return padPanel('pad/run_panel', '运行', 24, 96, 300, 880, [
    frame('pad/run/status_callout', {
      x: 24,
      y: 58,
      width: 252,
      height: 88,
      fill: c.warningTint,
      cornerRadius: 8,
      stroke: stroke(c.warningBorder),
      layout: 'none',
    }, [
      text('pad/run/status_title', '无障碍服务未开启', { x: 18, y: 18, fontSize: 17, fontWeight: '800', lineHeight: 1, fill: c.warning }),
      text('pad/run/status_desc', '需要先授权 AccessibilityService，启动后参数会锁定。', {
        x: 18,
        y: 50,
        width: 210,
        textGrowth: 'fixed-width',
        fontSize: 12,
        fontWeight: '500',
        lineHeight: 1.35,
        fill: '#74695E',
      }),
    ]),
    text('pad/run/action_type_label', '动作类型', { x: 24, y: 176, fontSize: 12, fontWeight: '900', lineHeight: 1, fill: c.muted }),
    frame('pad/run/action_segment', {
      x: 24,
      y: 198,
      width: 252,
      height: 40,
      fill: c.mutedSurface,
      cornerRadius: 8,
      layout: 'horizontal',
      padding: 4,
    }, [
      centeredTextButton('pad/run/action_swipe_selected', '滑动', { box: { width: 'fill_container', height: 'fill_container' }, radius: 6 }),
      frame('pad/run/action_tap', { width: 'fill_container', height: 'fill_container', layout: 'horizontal', justifyContent: 'center', alignItems: 'center' }, [
        text('pad/run/action_tap_text', '点击', { fontSize: 13, fontWeight: '800', fill: c.muted }),
      ]),
      frame('pad/run/action_multi', { width: 'fill_container', height: 'fill_container', layout: 'horizontal', justifyContent: 'center', alignItems: 'center' }, [
        text('pad/run/action_multi_text', '连击', { fontSize: 13, fontWeight: '800', fill: c.muted }),
      ]),
    ]),
    text('pad/run/direction_label', '滑动方向', { x: 24, y: 270, fontSize: 12, fontWeight: '900', lineHeight: 1, fill: c.muted }),
    centeredTextButton('pad/run/direction_up_selected', '向上', {
      box: { x: 24, y: 292, width: 118, height: 36 },
      fill: c.successTint,
      border: '#A9C8BA',
      color: c.success,
    }),
    centeredTextButton('pad/run/direction_down', '向下', {
      box: { x: 158, y: 292, width: 118, height: 36 },
      border: c.border,
    }),
    text('pad/run/preview_label', '运行预览', { x: 24, y: 366, fontSize: 12, fontWeight: '900', lineHeight: 1, fill: c.muted }),
    frame('pad/run/preview_box', {
      x: 24,
      y: 388,
      width: 252,
      height: 156,
      fill: '#F8FAFB',
      cornerRadius: 8,
      stroke: stroke('#E0E3E8'),
      layout: 'vertical',
      gap: 18,
      padding: 18,
    }, [
      text('pad/run/preview_action', '动作：向上滑动', { fontSize: 13, fontWeight: '800' }),
      text('pad/run/preview_interval', '间隔：3.0 - 8.0 秒', { fontSize: 13, fontWeight: '800' }),
      text('pad/run/preview_random', '随机：像真人，散点 10 px', { fontSize: 13, fontWeight: '800' }),
      text('pad/run/preview_multi', '连击：3 次，每次间隔 100 ms', { fontSize: 12, fontWeight: '600', fill: c.muted }),
    ]),
    text('pad/run/hint', '启动后自动收起，保留悬浮控制条。', {
      x: 24,
      y: 702,
      width: 220,
      textGrowth: 'fixed-width',
      fontSize: 12,
      fontWeight: '500',
      lineHeight: 1.35,
      fill: c.muted,
    }),
    centeredTextButton('pad/run/start_target_disabled', '启动并切到目标 App', {
      box: { x: 24, y: 740, width: 252, height: 44 },
      fill: c.mutedSurface,
      border: c.border,
      color: c.faint,
      fontSize: 14,
    }),
    centeredTextButton('pad/run/settings_button', '打开设置', { box: { x: 24, y: 800, width: 118, height: 38 } }),
    centeredTextButton('pad/run/stop_disabled', '停止', {
      box: { x: 158, y: 800, width: 118, height: 38 },
      fill: c.mutedSurface,
      border: c.border,
      color: c.faint,
    }),
  ]);
}

function padInput(name, value, x, y, width, disabled = false) {
  return frame(name, {
    x,
    y,
    width,
    height: 34,
    fill: disabled ? c.mutedSurface : c.strong,
    cornerRadius: 7,
    stroke: stroke(disabled ? c.border : c.strongBorder),
    layout: 'horizontal',
    justifyContent: 'center',
    alignItems: 'center',
  }, [
    text(`${name}/text`, value, { fontSize: 14, fontWeight: '900', fill: disabled ? c.faint : c.text }),
  ]);
}

function padStepper(name, value, y) {
  return [
    centeredTextButton(`${name}/minus`, '−', { box: { x: 368, y, width: 34, height: 34 }, fill: c.mutedSurface, border: c.border, fontSize: 17 }),
    padInput(`${name}/value`, value, 414, y, 92),
    centeredTextButton(`${name}/plus`, '+', { box: { x: 518, y, width: 34, height: 34 }, fill: c.mutedSurface, border: c.border, fontSize: 17 }),
  ];
}

function padParametersPanel() {
  return padPanel('pad/parameters_panel', '参数', 348, 96, 620, 648, [
    rect('pad/parameters/divider_1', { x: 0, y: 64, width: 620, height: 1, fill: '#EEF0F3' }),
    rect('pad/parameters/divider_2', { x: 0, y: 194, width: 620, height: 1, fill: '#EEF0F3' }),
    rect('pad/parameters/divider_3', { x: 0, y: 324, width: 620, height: 1, fill: '#EEF0F3' }),
    rect('pad/parameters/divider_4', { x: 0, y: 454, width: 620, height: 1, fill: '#EEF0F3' }),
    text('pad/parameters/min_label', '最小间隔', { x: 28, y: 92, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    text('pad/parameters/min_hint', '每次动作后的最短等待时间', { x: 28, y: 120, fontSize: 12, fontWeight: '500', lineHeight: 1, fill: c.muted }),
    ...padStepper('pad/parameters/min', '3.0 秒', 88),
    text('pad/parameters/max_label', '最大间隔', { x: 28, y: 222, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    text('pad/parameters/max_hint', '随机等待不会超过该值', { x: 28, y: 250, fontSize: 12, fontWeight: '500', lineHeight: 1, fill: c.muted }),
    ...padStepper('pad/parameters/max', '8.0 秒', 218),
    rect('pad/parameters/range_bg', { x: 28, y: 298, width: 524, height: 4, fill: '#D8DDE5', cornerRadius: 2 }),
    rect('pad/parameters/range_fill', { x: 78, y: 298, width: 128, height: 4, fill: c.success, cornerRadius: 2 }),
    frame('pad/parameters/range_min_thumb', { x: 70, y: 290, width: 18, height: 18, fill: c.success, cornerRadius: 9 }),
    frame('pad/parameters/range_max_thumb', { x: 198, y: 290, width: 18, height: 18, fill: c.success, cornerRadius: 9 }),
    text('pad/parameters/random_label', '随机强度', { x: 28, y: 352, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    text('pad/parameters/random_hint', '控制停顿和落点抖动，避免机械重复', { x: 28, y: 380, fontSize: 12, fontWeight: '500', lineHeight: 1, fill: c.muted }),
    text('pad/parameters/random_value', '像真人', { x: 482, y: 352, fontSize: 14, fontWeight: '900', lineHeight: 1, fill: c.success }),
    rect('pad/parameters/random_track_bg', { x: 28, y: 426, width: 524, height: 4, fill: '#D8DDE5', cornerRadius: 2 }),
    rect('pad/parameters/random_track_fill', { x: 28, y: 426, width: 330, height: 4, fill: c.success, cornerRadius: 2 }),
    frame('pad/parameters/random_thumb', { x: 350, y: 418, width: 18, height: 18, fill: c.success, cornerRadius: 9 }),
    text('pad/parameters/multi_tap_label', '连击参数', { x: 28, y: 482, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    text('pad/parameters/multi_tap_hint', '仅在连击模式下启用', { x: 28, y: 510, fontSize: 12, fontWeight: '500', lineHeight: 1, fill: c.muted }),
    text('pad/parameters/count_label', '次数', { x: 304, y: 482, fontSize: 12, fontWeight: '900', lineHeight: 1, fill: c.muted }),
    padInput('pad/parameters/count_input_disabled', '3 次', 360, 470, 74, true),
    text('pad/parameters/multi_interval_label', '间隔', { x: 304, y: 538, fontSize: 12, fontWeight: '900', lineHeight: 1, fill: c.muted }),
    padInput('pad/parameters/multi_interval_input_disabled', '100 ms', 360, 526, 88, true),
    text('pad/parameters/anchor_label', '点击锚点', { x: 28, y: 586, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    switchNode('pad/parameters/anchor_switch_off', false, { x: 472, y: 578 }),
  ]);
}

function padAssistPanel() {
  return padPanel('pad/assist_panel', '辅助', 992, 96, 350, 648, [
    rect('pad/assist/divider_1', { x: 0, y: 64, width: 350, height: 1, fill: '#EEF0F3' }),
    rect('pad/assist/divider_2', { x: 0, y: 198, width: 350, height: 1, fill: '#EEF0F3' }),
    rect('pad/assist/divider_3', { x: 0, y: 420, width: 350, height: 1, fill: '#EEF0F3' }),
    text('pad/assist/destination_label', '去向', { x: 28, y: 92, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    centeredTextButton('pad/assist/previous_selected', '上一个', { box: { x: 28, y: 122, width: 108, height: 34 }, fill: c.successTint, border: '#A9C8BA', color: c.success }),
    centeredTextButton('pad/assist/selected_app_button', '指定 App', { box: { x: 146, y: 122, width: 112, height: 34 }, border: c.border, color: c.muted }),
    text('pad/assist/destination_desc', '启动后收起主界面，回到刚才使用的应用或桌面。', { x: 28, y: 166, width: 268, textGrowth: 'fixed-width', fontSize: 12, fontWeight: '500', lineHeight: 1.35, fill: c.muted }),
    text('pad/assist/overlay_label', '小窗口', { x: 28, y: 224, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    switchNode('pad/assist/overlay_switch_on', true, { x: 260, y: 222 }),
    frame('pad/assist/overlay_info_box', { x: 28, y: 282, width: 292, height: 40, fill: c.mutedSurface, cornerRadius: 7, stroke: stroke(c.border), layout: 'horizontal', alignItems: 'center', padding: [0, 14] }, [
      text('pad/assist/overlay_info_text', '运行时悬浮：暂停 / 停止 / 收起', { width: 'fill_container', textGrowth: 'fixed-width', fontSize: 12, fontWeight: '500', fill: c.muted }),
    ]),
    centeredTextButton('pad/assist/snap_left_button', '靠左', { box: { x: 28, y: 344, width: 92, height: 34 } }),
    centeredTextButton('pad/assist/snap_right_button', '靠右', { box: { x: 132, y: 344, width: 92, height: 34 } }),
    frame('pad/assist/floating_control_preview', { x: 236, y: 342, width: 84, height: 34, fill: c.dark, cornerRadius: 17, layout: 'horizontal', justifyContent: 'center', alignItems: 'center' }, [
      text('pad/assist/floating_control_text', '暂停  停止', { fontSize: 11, fontWeight: '800', fill: c.strong }),
    ]),
    text('pad/assist/target_label', '标靶', { x: 28, y: 444, fontSize: 15, fontWeight: '900', lineHeight: 1 }),
    frame('pad/assist/coordinate_badge', { x: 188, y: 438, width: 104, height: 24, fill: c.mutedSurface, cornerRadius: 12, stroke: stroke(c.border), layout: 'horizontal', justifyContent: 'center', alignItems: 'center' }, [
      text('pad/assist/coordinate_text', 'x: --  y: --', { fontSize: 11, fontWeight: '900', fill: c.muted }),
    ]),
    frame('pad/assist/target_preview_box', { x: 28, y: 492, width: 292, height: 86, fill: '#F8FAFB', cornerRadius: 8, stroke: stroke('#E0E3E8'), layout: 'none' }, [
      text('pad/assist/target_desc', '用于选择点击点，或校准滑动起止位置。', { x: 16, y: 20, width: 190, textGrowth: 'fixed-width', fontSize: 12, fontWeight: '500', lineHeight: 1.45, fill: c.muted }),
      frame('pad/assist/target_ring', { x: 232, y: 26, width: 34, height: 34, fill: c.strong, cornerRadius: 17, stroke: stroke(c.success, 3) }),
      rect('pad/assist/target_cross_h', { x: 223, y: 42, width: 52, height: 2, fill: c.success }),
      rect('pad/assist/target_cross_v', { x: 248, y: 17, width: 2, height: 52, fill: c.success }),
    ]),
    centeredTextButton('pad/assist/show_target_button', '显示标靶', { box: { x: 28, y: 590, width: 92, height: 34 } }),
    centeredTextButton('pad/assist/calibrate_target_button', '校准位置', { box: { x: 132, y: 590, width: 116, height: 34 } }),
  ]);
}

function padDebugPanel() {
  return padPanel('pad/debug_log_panel', '调试日志', 348, 768, 994, 208, [
    rect('pad/debug/divider', { x: 0, y: 64, width: 994, height: 1, fill: '#EEF0F3' }),
    text('pad/debug/manual_label', '手动开启', { x: 134, y: 28, fontSize: 12, fontWeight: '900', lineHeight: 1, fill: c.muted }),
    switchNode('pad/debug/switch_off', false, { x: 204, y: 20 }),
    frame('pad/debug/state_badge', { x: 268, y: 23, width: 66, height: 22, fill: c.mutedSurface, cornerRadius: 11, stroke: stroke(c.border), layout: 'horizontal', justifyContent: 'center', alignItems: 'center' }, [
      text('pad/debug/state_text', '默认关闭', { fontSize: 10, fontWeight: '900', fill: c.muted }),
    ]),
    text('pad/debug/path_text', '关闭时不写入日志，避免长期运行生成大文件。路径：/data/user/0/com.example.auto_swiper/files/debug.log', {
      x: 28,
      y: 88,
      width: 720,
      textGrowth: 'fixed-width',
      fontSize: 12,
      fontWeight: '500',
      lineHeight: 1,
      fill: c.muted,
    }),
    frame('pad/debug/log_box', { x: 28, y: 118, width: 734, height: 58, fill: '#F8FAFB', cornerRadius: 7, stroke: stroke('#E0E3E8'), layout: 'vertical', gap: 10, padding: 16 }, [
      text('pad/debug/log_line_1', '日志关闭：仅保留本页状态，不落盘写入。', { fontSize: 12, fontWeight: '500', fill: '#47515D' }),
      text('pad/debug/log_line_2', '开启后记录动作、间隔、标靶坐标和异常，建议排查完成后关闭。', { fontSize: 12, fontWeight: '500', fill: c.muted }),
    ]),
    centeredTextButton('pad/debug/clear_button', '清空', { box: { x: 800, y: 118, width: 82, height: 36 } }),
    centeredTextButton('pad/debug/copy_button', '复制', { box: { x: 894, y: 118, width: 82, height: 36 } }),
  ]);
}

function pad() {
  return frame('layout / Pad', {
    x: 520,
    y: 0,
    width: 1366,
    height: 1024,
    fill: c.canvas,
    cornerRadius: 0,
    stroke: stroke(c.strongBorder),
    layout: 'none',
    clip: true,
  }, [
    padTopBar(),
    padRunPanel(),
    padParametersPanel(),
    padAssistPanel(),
    padDebugPanel(),
  ]);
}

const document = {
  version: '2.11',
  children: [
    phone(),
    pad(),
  ],
};

await writeFile(outFile, `${JSON.stringify(document, null, 2)}\n`, 'utf8');
console.log(outFile);
