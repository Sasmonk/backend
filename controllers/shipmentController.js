const { createClient } = require('@supabase/supabase-js');

// Helper to create a Supabase client that acts on behalf of the logged-in user
const getUserClient = (req) => {
  const token = req.headers.authorization.split(' ')[1];
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
};

// Use the Service Role for system-level actions that bypass RLS
const getAdminClient = () => {
    return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
}

exports.createShipment = async (req, res, next) => {
  const supabase = getUserClient(req);
  const { data, error } = await supabase.rpc('create_shipment_with_items', { ...req.body });
  if (error) return next(error);
  res.status(201).json({ success: true, data });
};

exports.getActiveShipments = async (req, res, next) => {
  const supabase = getUserClient(req);
  const { data, error } = await supabase.from('v_shipment_details').select('*').in('shipment_status', ['pending', 'in_transit']);
  if (error) return next(error);
  res.status(200).json({ success: true, data });
};

exports.getCompletedShipments = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('v_shipment_details').select('*').in('shipment_status', ['delivered', 'partially_delivered', 'cancelled']);
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.getShipmentById = async (req, res, next) => {
  const supabase = getUserClient(req);
  const { data, error } = await supabase.rpc('get_shipment_realtime_status', { p_shipment_id: req.params.id });
  if (error) return next(error);
  res.status(200).json({ success: true, data });
};

exports.updateShipmentStatus = async (req, res, next) => {
    const supabase = getUserClient(req);
    // Users can only perform safe status updates, like cancelling a pending shipment
    const { status } = req.body;
    if (status !== 'cancelled') {
        return res.status(400).json({ success: false, error: 'Invalid status update.'});
    }
    const { data, error } = await supabase.from('shipments').update({ status }).eq('id', req.params.id).eq('status', 'pending');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.deleteShipment = async (req, res, next) => {
  const supabase = getUserClient(req);
  // Only allow deletion if the shipment is still 'pending'
  const { data, error } = await supabase.from('shipments').delete().eq('id', req.params.id).eq('status', 'pending');
  if (error) return next(error);
  res.status(200).json({ success: true, message: 'Shipment deleted.' });
};

exports.completeShipmentVerification = async (req, res, next) => {
  // This is a system action that needs to bypass RLS to update multiple tables, so we use the admin client.
  const supabase = getAdminClient();
  const { data, error } = await supabase.rpc('complete_delivery_verification', { p_shipment_id: req.params.id });
  if (error) return next(error);
  res.status(200).json({ success: true, data });
};
