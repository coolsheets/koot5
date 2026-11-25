-- 1. East Kootenay Municipalities & BC Climate Zones
CREATE TABLE IF NOT EXISTS climate_zones (
  id SERIAL PRIMARY KEY,
  municipality VARCHAR(100) NOT NULL UNIQUE,
  climate_zone VARCHAR(10) NOT NULL,          -- e.g., '6' or '7A'
  hdd_18c INTEGER NOT NULL,                   -- Heating Degree Days (below 18°C)
  winter_design_temp_c NUMERIC(4,1) NOT NULL, -- 2.5% January design temp (°C)
  step5_max_tedi NUMERIC(5,2) NOT NULL,       -- Target TEDI (kWh/m²/yr)
  step5_max_meui NUMERIC(5,2) NOT NULL,       -- Target MEUI (kWh/m²/yr)
  step5_max_ach50 NUMERIC(3,2) DEFAULT 1.00   -- Airtightness target (ACH @ 50Pa)
);

-- 2. Envelope Assemblies (Walls, Roofs, Slabs, Windows)
CREATE TABLE IF NOT EXISTS assemblies (
  id SERIAL PRIMARY KEY,
  category VARCHAR(30) NOT NULL,              -- 'wall', 'roof', 'foundation', 'window'
  name VARCHAR(150) NOT NULL,
  effective_r_value NUMERIC(5,2),             -- Imperial R-value (for walls/roofs/slabs)
  u_value_si NUMERIC(4,3),                    -- Metric U-value W/(m²·K) (for windows)
  cost_cad_per_sqft NUMERIC(7,2) NOT NULL,    -- Estimated East Kootenay installed cost
  embodied_carbon_kg_co2e NUMERIC(6,2),       -- Optional upfront carbon metric
  notes TEXT
);

-- 3. Mechanical & Ventilation Systems (Heat Pumps, HRVs, DHW)
CREATE TABLE IF NOT EXISTS mechanical_systems (
  id SERIAL PRIMARY KEY,
  system_type VARCHAR(30) NOT NULL,           -- 'heating', 'ventilation', 'dhw'
  name VARCHAR(150) NOT NULL,
  efficiency_rating NUMERIC(5,2) NOT NULL,    -- COP at -15°C (heating), SRE % (HRV), or UEF (DHW)
  cost_cad NUMERIC(9,2) NOT NULL,
  rebate_eligible_cad NUMERIC(8,2) DEFAULT 0  -- CleanBC / FortisBC potential rebate
);

-- 4. User Residential Design Projects
CREATE TABLE IF NOT EXISTS projects (
  id SERIAL PRIMARY KEY,
  project_name VARCHAR(150) NOT NULL,
  climate_zone_id INTEGER REFERENCES climate_zones(id),
  conditioned_floor_area_m2 NUMERIC(8,2) NOT NULL,
  building_volume_m3 NUMERIC(9,2) NOT NULL,
  wall_area_m2 NUMERIC(8,2) NOT NULL,
  roof_area_m2 NUMERIC(8,2) NOT NULL,
  foundation_area_m2 NUMERIC(8,2) NOT NULL,
  window_area_m2 NUMERIC(8,2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. Design Iterations (Links a Project to Selected Assemblies & Results)
CREATE TABLE IF NOT EXISTS design_iterations (
  id SERIAL PRIMARY KEY,
  project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
  iteration_name VARCHAR(100) NOT NULL,
  wall_assembly_id INTEGER REFERENCES assemblies(id),
  roof_assembly_id INTEGER REFERENCES assemblies(id),
  foundation_assembly_id INTEGER REFERENCES assemblies(id),
  window_assembly_id INTEGER REFERENCES assemblies(id),
  heating_system_id INTEGER REFERENCES mechanical_systems(id),
  ventilation_system_id INTEGER REFERENCES mechanical_systems(id),
  target_ach50 NUMERIC(3,2) DEFAULT 1.00,
  calculated_tedi NUMERIC(6,2),
  calculated_meui NUMERIC(6,2),
  estimated_incremental_cost_cad NUMERIC(10,2),
  passes_step5 BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed East Kootenay Municipalities (Approximate BCBC Climate Data & Step 5 Benchmarks)
INSERT INTO climate_zones (municipality, climate_zone, hdd_18c, winter_design_temp_c, step5_max_tedi, step5_max_meui)
VALUES
  ('Cranbrook', '6', 4750, -24.0, 20.0, 30.0),
  ('Marysville', '6', 4850, -24.5, 20.0, 30.0),
  ('Kimberley', '6', 4950, -25.0, 20.0, 30.0),
  ('Invermere', '6', 4850, -25.0, 20.0, 30.0),
  ('Fernie', '7A', 5250, -27.0, 25.0, 35.0),
  ('Sparwood', '7A', 5400, -28.0, 25.0, 35.0),
  ('Golden', '7A', 5300, -27.0, 25.0, 35.0)
ON CONFLICT (municipality) DO NOTHING;

-- Seed Starter Step 5 Envelope Assemblies
INSERT INTO assemblies (category, name, effective_r_value, u_value_si, cost_cad_per_sqft, notes)
VALUES
  ('wall', '2x6 Framing + 3" Exterior Mineral Wool (R-32 Eff.)', 32.0, NULL, 28.50, 'Strong thermal bridge control for Zone 6/7A'),
  ('wall', 'Double Stud 2x4 Wall w/ Dense-Pack Cellulose (R-40 Eff.)', 40.0, NULL, 34.00, 'Ideal for Fernie/Golden Step 5 TEDI targets'),
  ('roof', 'Raised-Heel Truss w/ R-60 Blown Cellulose', 60.0, NULL, 18.00, 'Standard Step 5 attic assembly'),
  ('roof', 'Vaulted TJI w/ 4" Exterior Polyiso + Dense Pack (R-55 Eff.)', 55.0, NULL, 26.50, 'High-performance cathedral ceiling'),
  ('foundation', 'Sub-Slab 4" XPS Foam + R-24 ICF Frost Wall', 24.0, NULL, 24.00, 'Prevents deep frost heat loss in East Kootenays'),
  ('window', 'Triple-Pane Fiberglass Low-E Argon (U-0.80)', NULL, 0.800, 95.00, 'Meets cold-climate Step 5 solar/thermal balance'),
  ('window', 'Passive House Certified Triple-Pane uPVC (U-0.68)', NULL, 0.680, 115.00, 'Maximizes passive solar gain on south elevations');
