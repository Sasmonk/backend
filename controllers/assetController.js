const { createClient } = require('@supabase/supabase-js');

// Helper to create a Supabase client that acts on behalf of the logged-in user
const getUserClient = (req) => {
  const token = req.headers.authorization.split(' ')[1];
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
};

// --- PRODUCT CONTROLLERS ---
exports.getProducts = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('products').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.createProduct = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('products').insert([req.body]).select();
    if (error) return next(error);
    res.status(201).json({ success: true, data });
};

exports.updateProduct = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('products').update(req.body).eq('id', req.params.id).select();
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.deleteProduct = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { error } = await supabase.from('products').delete().eq('id', req.params.id);
    if (error) return next(error);
    res.status(204).end(); // Correctly sends 204 and ends the response
};

// --- TRUCK CONTROLLERS ---
exports.getTrucks = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('trucks').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.createTruck = async (req, res, next) => {
    const supabase = getUserClient(req);
    // Note: In a real app, you'd associate this truck with the user's company via company_trucks table
    const { data, error } = await supabase.from('trucks').insert([req.body]).select();
    if (error) return next(error);
    res.status(201).json({ success: true, data });
};


// --- DESTINATION CONTROLLERS ---
exports.getDestinations = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('rfid_destinations').select('*');
    if (error) return next(error);
    res.status(200).json({ success: true, data });
};

exports.createDestination = async (req, res, next) => {
    const supabase = getUserClient(req);
    const { data, error } = await supabase.from('rfid_destinations').insert([req.body]).select();
    if (error) return next(error);
    res.status(201).json({ success: true, data });
};
