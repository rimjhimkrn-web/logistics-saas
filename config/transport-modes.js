export const TRANSPORT_MODES = {
  ROAD_RAIL: {
    id: 'road-rail',
    name: 'Road & Rail',
    icon: 'truck',
    units: ['kg', 'lbs', 'cbm', 'pallet'],
    allowsDangerousGoods: true,
    requiresTemperatureControl: true
  },
  OCEAN: {
    id: 'ocean',
    name: 'Ocean Freight',
    icon: 'ship',
    units: ['teu', 'feu', 'cbm', 'kg'],
    containerTypes: ['20GP', '40GP', '40HC', 'Reefer', 'FlatRack'],
    allowsDangerousGoods: true
  },
  AIR: {
    id: 'air',
    name: 'Air Cargo',
    icon: 'plane',
    units: ['kg', 'lbs', 'volumetric_kg'],
    dimensionalFactor: 6000, // Standard IATA ratio (cm³/kg)
    allowsDangerousGoods: true
  },
  EXPRESS: {
    id: 'express',
    name: 'Express Courier',
    icon: 'zap',
    units: ['kg', 'lbs'],
    dimensionalFactor: 5000,
    maxWeightPerPieceKg: 70
  },
  WAREHOUSING: {
    id: 'warehousing',
    name: 'Warehousing & Fulfillment',
    icon: 'warehouse',
    units: ['pallet', 'sqm', 'sqft', 'sku_count']
  }
};
