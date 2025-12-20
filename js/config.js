// Configuration for EV Modelling Web Visualization

const CONFIG = {
    // PMTiles base URL (served from same origin for CORS)
    pmtilesBaseUrl: 'pmtiles',

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
            colorProperty: 'adoption_propensity_score',
            colorScale: 'viridis',
            legendTitle: 'Adoption Score'
        },
        {
            id: 'charging_network',
            name: 'Charging Network',
            type: 'polygon',
            description: 'Charging infrastructure accessibility',
            colorProperty: 'accessibility_score',
            colorScale: 'plasma',
            legendTitle: 'Accessibility Score'
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
            colorProperty: 'conversion_potential',
            colorScale: 'viridis',
            legendTitle: 'Conversion Potential'
        },
        {
            id: 'ev_assignment_replaceable_only',
            name: 'EV Assignment',
            type: 'polygon',
            description: '2-seater vs 4-seater assignment',
            colorProperty: 'ev_type',
            colorScale: 'ev_type',
            legendTitle: 'EV Type'
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
            'one_way_only': '#f39c12',
            'constrained': '#e67e22',
            'infeasible': '#e74c3c',
            'unknown': '#95a5a6'
        },
        ev_type: {
            '2-seater': '#3498db',
            '4-seater': '#9b59b6',
            'either': '#1abc9c',
            'not_applicable': '#95a5a6'
        },
        categorical: {
            'Commuting': '#e74c3c',
            'Education': '#3498db',
            'Shopping': '#2ecc71',
            'Personal business': '#9b59b6',
            'Escort': '#f39c12',
            'Visiting': '#1abc9c',
            'Leisure': '#e91e63',
            'Other': '#95a5a6'
        }
    },

    // Basemap style
    basemapStyle: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
};
