// Configuration for EV Modelling Web Visualization

const CONFIG = {
    // PMTiles base URL (using jsDelivr CDN for proper range request support)
    // Using commit hash to bust CDN cache
    pmtilesBaseUrl: 'https://cdn.jsdelivr.net/gh/wangzhao0217/zev-up.github.io@53a8b59/pmtiles',

    // Available PMTiles files (region_stage combinations that exist)
    availableFiles: [
        'chargers',
        'car_availability',
        'ev_distribution',
        // HITRANS
        'hitrans_adoption_propensity',
        'hitrans_charging_network',
        'hitrans_conversion_potential',
        'hitrans_ev_assignment_replaceable_only',
        'hitrans_integrated_conversion_with_ev_types',
        'hitrans_range_feasibility',
        'hitrans_trip_purpose',
        // Nestrans
        'nestrans_adoption_propensity',
        'nestrans_charging_network',
        'nestrans_conversion_potential',
        'nestrans_ev_assignment_replaceable_only',
        'nestrans_integrated_conversion_with_ev_types',
        'nestrans_range_feasibility',
        'nestrans_trip_purpose',
        // SESTRAN
        'sestran_adoption_propensity',
        'sestran_charging_network',
        'sestran_conversion_potential',
        'sestran_ev_assignment_replaceable_only',
        'sestran_integrated_conversion_with_ev_types',
        'sestran_range_feasibility',
        'sestran_trip_purpose',
        // SPT
        'spt_adoption_propensity',
        'spt_charging_network',
        'spt_conversion_potential',
        'spt_ev_assignment_replaceable_only',
        'spt_integrated_conversion_with_ev_types',
        'spt_range_feasibility',
        'spt_trip_purpose',
        // SWESTRANS
        'swestrans_adoption_propensity',
        'swestrans_charging_network',
        'swestrans_conversion_potential',
        'swestrans_ev_assignment_replaceable_only',
        'swestrans_integrated_conversion_with_ev_types',
        'swestrans_range_feasibility',
        'swestrans_trip_purpose',
        // Tactran
        'tactran_adoption_propensity',
        'tactran_charging_network',
        'tactran_conversion_potential',
        'tactran_ev_assignment_replaceable_only',
        'tactran_integrated_conversion_with_ev_types',
        'tactran_range_feasibility',
        'tactran_trip_purpose',
        // ZetTrans
        'zettrans_adoption_propensity',
        'zettrans_charging_network',
        'zettrans_conversion_potential',
        'zettrans_ev_assignment_replaceable_only',
        'zettrans_integrated_conversion_with_ev_types',
        'zettrans_range_feasibility',
        'zettrans_trip_purpose'
    ],

    // Overlay layers (Scotland-wide, not region-specific)
    overlayLayers: [
        {
            id: 'car_availability',
            name: 'Car/Van Availability',
            type: 'polygon',
            description: 'Household car ownership from 2011 Census',
            colorProperty: 'car_ownership_rate',
            colorScale: 'viridis',
            legendTitle: 'Car Ownership Rate',
            sourceLayer: 'car_availability'
        },
        {
            id: 'ev_distribution',
            name: 'EV Distribution',
            type: 'polygon',
            description: 'Current EV registrations by postcode area',
            colorProperty: 'bev_share',
            colorScale: 'plasma',
            legendTitle: 'BEV Share (%)',
            sourceLayer: 'ev_distribution'
        }
    ],

    // Map settings
    map: {
        center: [-4.0, 56.5],  // Scotland center
        zoom: 6,
        minZoom: 5,
        maxZoom: 14,
        bounds: [
            [-8.0, 54.5],  // Southwest
            [0.0, 61.0]    // Northeast
        ]
    },

    // Regions
    regions: [
        { id: 'hitrans', name: 'HITRANS', center: [-5.5, 57.5], zoom: 7 },
        { id: 'nestrans', name: 'Nestrans', center: [-2.1, 57.15], zoom: 9 },
        { id: 'sestran', name: 'SESTRAN', center: [-3.2, 55.95], zoom: 9 },
        { id: 'spt', name: 'SPT', center: [-4.25, 55.85], zoom: 9 },
        { id: 'swestrans', name: 'SWESTRANS', center: [-4.0, 55.1], zoom: 9 },
        { id: 'tactran', name: 'Tactran', center: [-3.8, 56.5], zoom: 8 },
        { id: 'zettrans', name: 'ZetTrans', center: [-1.2, 60.4], zoom: 9 }
    ],

    // Analysis stages
    stages: [
        {
            id: 'adoption_propensity',
            name: 'Adoption Propensity',
            type: 'polygon',
            description: 'Demographic-based EV adoption likelihood',
            colorProperty: 'final_adoption_propensity',
            colorScale: 'viridis',
            legendTitle: 'Final Adoption Propensity'
        },
        {
            id: 'charging_network',
            name: 'Charging Network',
            type: 'polygon',
            description: 'Charging infrastructure accessibility',
            colorProperty: 'charging_accessibility_category',
            colorScale: 'charging_category',
            legendTitle: 'Charging Accessibility'
        },
        {
            id: 'trip_purpose',
            name: 'Trip Purpose',
            type: 'line',
            description: 'Trip purpose suitability analysis',
            colorProperty: 'purpose',
            colorScale: 'categorical',
            legendTitle: 'Trip Purpose'
        },
        {
            id: 'range_feasibility',
            name: 'Range Feasibility',
            type: 'line',
            description: '100km range constraint analysis',
            colorProperty: 'feasibility_category',
            colorScale: 'feasibility',
            legendTitle: 'Feasibility'
        },
        {
            id: 'conversion_potential',
            name: 'Conversion Potential',
            type: 'polygon',
            description: 'Trip conversion potential',
            colorProperty: 'purpose_weight',
            colorScale: 'viridis',
            legendTitle: 'Purpose Weight'
        },
        {
            id: 'ev_assignment_replaceable_only',
            name: 'EV Assignment',
            type: 'polygon',
            description: '2-seater vs 4-seater assignment',
            colorProperty: 'ev_type_assignment',
            colorScale: 'ev_type',
            legendTitle: 'EV Type Assignment'
        },
        {
            id: 'integrated_conversion_with_ev_types',
            name: 'Integrated Analysis',
            type: 'polygon',
            description: 'Final integrated feasibility',
            colorProperty: 'integrated_score',
            colorScale: 'viridis',
            legendTitle: 'Integrated Score'
        }
    ],

    // Color scales
    colorScales: {
        viridis: [
            [0.0, '#440154'],
            [0.25, '#3b528b'],
            [0.5, '#21918c'],
            [0.75, '#5ec962'],
            [1.0, '#fde725']
        ],
        plasma: [
            [0.0, '#0d0887'],
            [0.25, '#7e03a8'],
            [0.5, '#cc4778'],
            [0.75, '#f89540'],
            [1.0, '#f0f921']
        ],
        feasibility: {
            'feasible': '#2ecc71',
            'constrained': '#f39c12',
            'infeasible': '#e74c3c'
        },
        charging_category: {
            'excellent': '#2ecc71',
            'good': '#27ae60',
            'fair': '#f39c12',
            'poor': '#e74c3c'
        },
        ev_type: {
            '2-seater': '#3498db',
            '4-seater': '#9b59b6',
            'mixed': '#1abc9c'
        },
        categorical: {
            'Commuting': '#e74c3c',
            'Business': '#c0392b',
            'Education': '#3498db',
            'shopping': '#2ecc71',
            'Other personal business': '#9b59b6',
            'Escort': '#f39c12',
            'Visiting friends or relatives': '#1abc9c',
            'Holiday/daytrip': '#e91e63',
            'Sport/Entertainment': '#00bcd4',
            'Eating/Drinking': '#ff9800',
            'Visit Hospital or other health': '#607d8b',
            'Other Journey': '#95a5a6'
        }
    },

    // Basemap styles
    basemaps: {
        'dark': {
            name: 'Dark',
            style: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
        },
        'light': {
            name: 'Light',
            style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json'
        },
        'osm': {
            name: 'OpenStreetMap',
            style: {
                version: 8,
                sources: {
                    'osm': {
                        type: 'raster',
                        tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
                        tileSize: 256,
                        attribution: '© OpenStreetMap contributors'
                    }
                },
                layers: [{
                    id: 'osm-tiles',
                    type: 'raster',
                    source: 'osm',
                    minzoom: 0,
                    maxzoom: 19
                }]
            }
        },
        'satellite': {
            name: 'Satellite',
            style: {
                version: 8,
                sources: {
                    'satellite': {
                        type: 'raster',
                        tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
                        tileSize: 256,
                        attribution: '© Esri'
                    }
                },
                layers: [{
                    id: 'satellite-tiles',
                    type: 'raster',
                    source: 'satellite',
                    minzoom: 0,
                    maxzoom: 19
                }]
            }
        },
        'satellite-streets': {
            name: 'Satellite + Roads',
            style: {
                version: 8,
                sources: {
                    'satellite': {
                        type: 'raster',
                        tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
                        tileSize: 256,
                        attribution: '© Esri'
                    },
                    'carto-labels': {
                        type: 'raster',
                        tiles: ['https://a.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png'],
                        tileSize: 256
                    }
                },
                layers: [
                    {
                        id: 'satellite-tiles',
                        type: 'raster',
                        source: 'satellite',
                        minzoom: 0,
                        maxzoom: 19
                    },
                    {
                        id: 'road-labels',
                        type: 'raster',
                        source: 'carto-labels',
                        minzoom: 0,
                        maxzoom: 19
                    }
                ]
            }
        }
    },

    // Default basemap
    defaultBasemap: 'light',

    // Basemap style (legacy - use basemaps instead)
    basemapStyle: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
};
