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

// --- 1. CREATE SHIPMENT ---
exports.createShipment = async (req, res, next) => {
  const supabase = getUserClient(req);
  
  // ✅ FIX: The parameter names now have the 'p_' prefix to match the database function.
  const { data, error } = await supabase.rpc('create_shipment_with_items', {
    p_company_id: req.body.company_id,
    p_truck_id: req.body.truck_id,
    p_destination_id: req.body.destination_id,
    p_origin_location: req.body.origin_location,
    p_estimated_arrival: req.body.estimated_arrival,
    p_items: req.body.items
  });

  if (error) {
    console.error("RPC Error in createShipment:", error); // Added for better debugging
    return next(error);
  }
  
  res.status(201).json({ success: true, data });
};

// --- 2. GET ACTIVE SHIPMENTS ---
exports.getActiveShipments = async (req, res, next) => {
  const supabase = getUserClient(req);
  const { data, error } = await supabase.from('v_shipment_details').select('*').in('shipment_status', ['pending', 'in_transit']);
  if (error) return next(error);
  res.status(200).json({ success: true, data });
};

// --- 3. GET COMPLETED SHIPMENTS (HISTORY) ---
exports.getCompletedShipments = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('v_shipment_details').select('*').in('shipment_status', ['delivered', 'partially_delivered', 'cancelled']);
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

// --- 4. GET SHIPMENT BY ID ---
exports.getShipmentById = async (req, res, next) => {
  const supabase = getUserClient(req);
  // This RPC function gets detailed real-time status for a single shipment
  const { data, error } = await supabase.rpc('get_shipment_realtime_status', { p_shipment_id: req.params.id });
  if (error) return next(error);
  res.status(200).json({ success: true, data });
};

// --- 5. UPDATE SHIPMENT STATUS ---
exports.updateShipmentStatus = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { status } = req.body;

    // ✅ FIX: Allow users to update status to 'in_transit' or 'cancelled'
    const allowed_statuses = ['in_transit', 'cancelled'];
    if (!allowed_statuses.includes(status)) {
        return res.status(400).json({ success: false, error: 'Invalid status for user update.' });
    }
    
    // RLS on the 'shipments' table ensures users can only update shipments for their own company.
    // We add an extra condition here to only allow updates on 'pending' shipments.
    const { data, error } = await supabase.from('shipments')
        .update({ status })
        .eq('id', req.params.id)
        .eq('status', 'pending')
        .select();

    if (error) return next(error);
    
    // If no data is returned, it means no row was updated (either not found or status was not 'pending')
    if (!data || data.length === 0) {
        return res.status(404).json({ success: false, error: 'Shipment not found or its status cannot be updated.' });
    }

    res.status(200).json({ success: true, data });
};

// --- 6. DELETE SHIPMENT ---
exports.deleteShipment = async (req, res, next) => {
  const supabase = getUserClient(req);
  
  // RLS ensures users can only delete shipments from their company.
  // We add an extra condition to only allow deletion of 'pending' shipments.
  const { error } = await supabase.from('shipments')
      .delete()
      .eq('id', req.params.id)
      .eq('status', 'pending');

  if (error) return next(error);

  // ✅ FIX: Return a 204 No Content response, which is the standard for a successful DELETE.
  res.status(204).end();
};

// --- 7. COMPLETE SHIPMENT VERIFICATION (ADMIN ACTION) ---
exports.completeShipmentVerification = async (req, res, next) => {
  // This is a powerful, system-level action that needs to bypass RLS to update multiple tables.
  // Therefore, we use the admin client which has elevated privileges.
  const supabase = getAdminClient();
  
  const { data, error } = await supabase.rpc('complete_delivery_verification', { 
    p_shipment_id: req.params.id,
    // In a real app, you would pass the verified item data from req.body
    // For this test, the RPC function will simulate the verification process.
  });

  if (error) return next(error);
  
  res.status(200).json({ success: true, data });
};