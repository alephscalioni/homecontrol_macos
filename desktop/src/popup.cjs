const pointValid = point => point && Number.isFinite(point.x) && Number.isFinite(point.y);
const rectValid = rect => pointValid(rect) && Number.isFinite(rect.width) && Number.isFinite(rect.height) && rect.width > 0 && rect.height > 0;
const contains = (rect, point) => point.x >= rect.x && point.y >= rect.y && point.x < rect.x + rect.width && point.y < rect.y + rect.height;

function activationPoint(position, cursor, displays) {
  // SNI hosts can omit event coordinates and pass (0, 0) instead.
  if (pointValid(position) && (position.x !== 0 || position.y !== 0) && displays.some(display => contains(display.bounds, position))) return position;
  return cursor;
}

function popupBounds(display, size, point, iconBounds) {
  const area = display.workArea, screen = display.bounds;
  const width = Math.min(size.width, area.width), height = Math.min(size.height, area.height);
  const icon = rectValid(iconBounds) ? iconBounds : null;
  const anchor = icon ? { x: icon.x + icon.width / 2, y: icon.y + icon.height / 2 } : pointValid(point) ? point : { x: area.x + area.width - 24, y: screen.y };
  const edges = [
    ['top', Math.abs(anchor.y - screen.y), area.y - screen.y],
    ['bottom', Math.abs(screen.y + screen.height - anchor.y), screen.y + screen.height - area.y - area.height],
    ['left', Math.abs(anchor.x - screen.x), area.x - screen.x],
    ['right', Math.abs(screen.x + screen.width - anchor.x), screen.x + screen.width - area.x - area.width]
  ].sort((a, b) => a[1] - b[1]);
  const reserved = edges.filter(edge => edge[2] > 0 && edge[1] <= edge[2] + 32);
  const nearest = reserved[0] || edges[0];
  const edge = nearest[1] <= Math.max(96, nearest[2] + 32) ? nearest[0] : 'top';
  let x = anchor.x - width / 2, y = area.y + 4;
  if (edge === 'top') y = icon ? icon.y + icon.height + 4 : area.y + 4;
  if (edge === 'bottom') y = icon ? icon.y - height - 4 : area.y + area.height - height - 4;
  if (edge === 'left' || edge === 'right') {
    x = edge === 'left' ? icon ? icon.x + icon.width + 4 : area.x + 4 : icon ? icon.x - width - 4 : area.x + area.width - width - 4;
    y = anchor.y - height / 2;
  }
  return { x: Math.round(Math.max(area.x, Math.min(x, area.x + area.width - width))), y: Math.round(Math.max(area.y, Math.min(y, area.y + area.height - height))), width, height };
}

module.exports = { activationPoint, popupBounds, rectValid };
