export function loginPermissions(role: string, grants: string[], denied: string[] = []): string[] {
  const defaults: Record<string, string[]> = {
    manager: ['pos_access', 'complete_sales', 'view_inventory', 'add_products', 'edit_products', 'manage_employees', 'adjust_stock'],
    sales_employee: ['pos_access', 'complete_sales', 'view_inventory'],
    inventory_employee: ['view_inventory', 'add_products', 'edit_products'],
    employee: [],
  };
  if (!(role in defaults)) return [];
  const price = new Set(['override_price', 'edit_prices', 'change_prices', 'manage_prices', 'set_prices', 'branch_price_override']);
  const ownerOnly = new Set(['view_camera_events', 'manage_permissions', 'assign_roles', 'owner_app']);
  return [...new Set([...defaults[role], ...grants])].filter(p =>
    !denied.includes(p) && !ownerOnly.has(p) && (!price.has(p) || role === 'manager') &&
    !(p === 'apply_discount' && role === 'inventory_employee') &&
    !(p === 'manage_employees' && role !== 'manager') &&
    p !== 'view_profit' && !(p === 'view_finance' && role !== 'manager'));
}
