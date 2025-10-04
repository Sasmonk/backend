const { createClient } = require('@supabase/supabase-js');

// Helper to create a Supabase client that acts on behalf of the logged-in user
const getUserClient = (req) => {
  const token = req.headers.authorization.split(' ')[1];
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
};

exports.getMissingProductsReport = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('v_missing_products_report').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.getTruckUtilizationReport = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('v_truck_utilization').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.getDeliveryPerformanceReport = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('v_delivery_performance').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.getSystemAlerts = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('v_alerts_monitoring').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};
