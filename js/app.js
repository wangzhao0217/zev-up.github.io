// Main application logic for EV Modelling Web Visualization

class EVModellingApp {
    constructor() {
        this.map = null;
        this.currentRegion = 'all';  // Default to all regions
        this.currentStage = 'adoption_propensity';
        this.currentBasemap = 'light';
        this.activeLayers = [];
        this.showChargers = true;  // Show chargers by default
        this.showAnalysisLayer = true;  // Show analysis layer by default
        this.showCarAvailability = false;  // Car availability overlay
        this.showEvDistribution = false;  // EV distribution overlay

        this.init();
    }

    /**
     * Initialize the application
     */
    async init() {
        // Register PMTiles protocol
        const protocol = new pmtiles.Protocol();
        maplibregl.addProtocol('pmtiles', protocol.tile);

        // Get initial basemap style
        const basemapConfig = CONFIG.basemaps[this.currentBasemap];
        const initialStyle = basemapConfig.style;

        // Initialize map
        this.map = new maplibregl.Map({
            container: 'map',
            style: initialStyle,
            center: CONFIG.map.center,
            zoom: CONFIG.map.zoom,
            minZoom: CONFIG.map.minZoom,
            maxZoom: CONFIG.map.maxZoom,
            maxBounds: CONFIG.map.bounds
        });

        // Add navigation controls
        this.map.addControl(new maplibregl.NavigationControl(), 'top-right');
        this.map.addControl(new maplibregl.ScaleControl(), 'bottom-right');

        // Wait for map to load
        this.map.on('load', () => {
            this.setupEventListeners();
            this.updateLayers();
            this.updateChargerLayer();
            this.updateOverlayLayers();
            this.updateLegend();
        });

        // Setup click handler for feature info
        this.map.on('click', (e) => this.handleMapClick(e));
    }

    /**
     * Setup UI event listeners
     */
    setupEventListeners() {
        // Basemap selector
        const basemapSelect = document.getElementById('basemap-select');
        basemapSelect.addEventListener('change', (e) => {
            this.currentBasemap = e.target.value;
            this.changeBasemap();
        });

        // Region selector
        const regionSelect = document.getElementById('region-select');
        regionSelect.addEventListener('change', (e) => {
            this.currentRegion = e.target.value;
            this.updateLayers();
            this.flyToRegion();
        });

        // Stage radio buttons
        const stageRadios = document.querySelectorAll('input[name="stage"]');
        stageRadios.forEach(radio => {
            radio.addEventListener('change', (e) => {
                this.currentStage = e.target.value;
                this.updateLayers();
                this.updateLegend();
            });
        });

        // Charger toggle
        const chargerToggle = document.getElementById('charger-toggle');
        if (chargerToggle) {
            chargerToggle.addEventListener('change', (e) => {
                this.showChargers = e.target.checked;
                this.updateChargerLayer();
            });
        }

        // Car availability toggle
        const carAvailabilityToggle = document.getElementById('car-availability-toggle');
        if (carAvailabilityToggle) {
            carAvailabilityToggle.addEventListener('change', (e) => {
                this.showCarAvailability = e.target.checked;
                this.updateOverlayLayers();
                this.updateLegend();
            });
        }

        // EV distribution toggle
        const evDistributionToggle = document.getElementById('ev-distribution-toggle');
        if (evDistributionToggle) {
            evDistributionToggle.addEventListener('change', (e) => {
                this.showEvDistribution = e.target.checked;
                this.updateOverlayLayers();
                this.updateLegend();
            });
        }

        // Analysis layer toggle
        const analysisLayerToggle = document.getElementById('analysis-layer-toggle');
        if (analysisLayerToggle) {
            analysisLayerToggle.addEventListener('change', (e) => {
                this.showAnalysisLayer = e.target.checked;
                const stageToggles = document.getElementById('stage-toggles');
                if (stageToggles) {
                    stageToggles.classList.toggle('disabled', !this.showAnalysisLayer);
                }
                this.updateLayers();
            });
        }

        // Close info panel
        const closeInfo = document.getElementById('close-info');
        closeInfo.addEventListener('click', () => {
            document.getElementById('info-panel').classList.add('hidden');
        });
    }

    /**
     * Change the basemap style
     */
    changeBasemap() {
        const basemapConfig = CONFIG.basemaps[this.currentBasemap];
        const newStyle = basemapConfig.style;

        // Store current center and zoom
        const center = this.map.getCenter();
        const zoom = this.map.getZoom();

        // Set new style
        this.map.setStyle(newStyle);

        // Re-add layers after style loads
        this.map.once('style.load', () => {
            this.map.setCenter(center);
            this.map.setZoom(zoom);
            this.updateLayers();
            this.updateChargerLayer();
            this.updateOverlayLayers();
        });
    }

    /**
     * Update overlay layers (car availability, EV distribution)
     */
    updateOverlayLayers() {
        // Car availability layer
        if (this.showCarAvailability) {
            LAYERS.addOverlayLayer(this.map, 'car_availability');
        } else {
            LAYERS.removeOverlayLayer(this.map, 'car_availability');
        }

        // EV distribution layer
        if (this.showEvDistribution) {
            LAYERS.addOverlayLayer(this.map, 'ev_distribution');
        } else {
            LAYERS.removeOverlayLayer(this.map, 'ev_distribution');
        }
    }

    /**
     * Update charger layer visibility
     */
    updateChargerLayer() {
        const sourceId = 'chargers-source';
        const layerId = 'chargers-layer';

        if (this.showChargers) {
            // Add source if not exists
            if (!this.map.getSource(sourceId)) {
                this.map.addSource(sourceId, {
                    type: 'vector',
                    url: `pmtiles://${CONFIG.pmtilesBaseUrl}/chargers.pmtiles`
                });
            }

            // Add layer if not exists
            if (!this.map.getLayer(layerId)) {
                this.map.addLayer({
                    id: layerId,
                    type: 'circle',
                    source: sourceId,
                    'source-layer': 'chargers',
                    paint: {
                        'circle-radius': [
                            'interpolate',
                            ['linear'],
                            ['zoom'],
                            6, 3,
                            10, 5,
                            14, 8
                        ],
                        'circle-color': '#22c55e',
                        'circle-stroke-color': '#ffffff',
                        'circle-stroke-width': 2,
                        'circle-opacity': 0.9
                    }
                });

                // Add click handler for chargers
                this.map.on('click', layerId, (e) => {
                    if (e.features.length > 0) {
                        const props = e.features[0].properties;
                        let html = '';
                        if (props.title) {
                            html += `<div class="info-row"><span class="info-label">Name</span><span class="info-value">${props.title}</span></div>`;
                        }
                        if (props.town) {
                            html += `<div class="info-row"><span class="info-label">Town</span><span class="info-value">${props.town}</span></div>`;
                        }
                        if (props.postcode) {
                            html += `<div class="info-row"><span class="info-label">Postcode</span><span class="info-value">${props.postcode}</span></div>`;
                        }
                        if (props.number_of_points) {
                            html += `<div class="info-row"><span class="info-label">Charging Points</span><span class="info-value">${props.number_of_points}</span></div>`;
                        }
                        document.getElementById('info-content').innerHTML = html;
                        document.getElementById('info-panel').classList.remove('hidden');
                    }
                });

                this.map.on('mouseenter', layerId, () => {
                    this.map.getCanvas().style.cursor = 'pointer';
                });
                this.map.on('mouseleave', layerId, () => {
                    this.map.getCanvas().style.cursor = '';
                });
            }
        } else {
            // Remove layer and source
            if (this.map.getLayer(layerId)) {
                this.map.removeLayer(layerId);
            }
            if (this.map.getSource(sourceId)) {
                this.map.removeSource(sourceId);
            }
        }
    }

    /**
     * Update map layers based on current selection
     */
    updateLayers() {
        // Remove existing layers
        this.activeLayers.forEach(layerId => {
            const parts = layerId.split('-');
            const region = parts[0];
            const stage = parts.slice(1).join('_');
            LAYERS.removeLayer(this.map, region, stage);
        });
        this.activeLayers = [];

        // Only add layers if analysis layer is enabled
        if (!this.showAnalysisLayer) {
            return;
        }

        // Determine which regions to show
        const regionsToShow = this.currentRegion === 'all'
            ? CONFIG.regions.map(r => r.id)
            : [this.currentRegion];

        // Add layers for each region (only if file exists)
        regionsToShow.forEach(region => {
            const fileKey = `${region}_${this.currentStage}`;
            if (CONFIG.availableFiles.includes(fileKey)) {
                try {
                    const layerId = LAYERS.addLayer(this.map, region, this.currentStage);
                    this.activeLayers.push(layerId);
                } catch (error) {
                    console.warn(`Failed to load layer for ${region}/${this.currentStage}:`, error);
                }
            }
        });

        // Update click handlers
        this.updateClickHandlers();
    }

    /**
     * Update click handlers for active layers
     */
    updateClickHandlers() {
        // Remove old handlers and add new ones
        this.activeLayers.forEach(layerId => {
            this.map.on('mouseenter', layerId, () => {
                this.map.getCanvas().style.cursor = 'pointer';
            });
            this.map.on('mouseleave', layerId, () => {
                this.map.getCanvas().style.cursor = '';
            });
        });
    }

    /**
     * Handle map click to show feature info
     */
    handleMapClick(e) {
        // Query features at click point
        const features = this.map.queryRenderedFeatures(e.point, {
            layers: this.activeLayers
        });

        if (features.length === 0) {
            document.getElementById('info-panel').classList.add('hidden');
            return;
        }

        const feature = features[0];
        const properties = feature.properties;

        // Build info content
        let html = '';
        const stageConfig = CONFIG.stages.find(s => s.id === this.currentStage);

        // Show key properties based on stage
        const keyProps = this.getKeyProperties(this.currentStage);
        keyProps.forEach(prop => {
            if (properties[prop] !== undefined) {
                const label = this.formatPropertyLabel(prop);
                const value = this.formatPropertyValue(prop, properties[prop]);
                html += `
                    <div class="info-row">
                        <span class="info-label">${label}</span>
                        <span class="info-value">${value}</span>
                    </div>
                `;
            }
        });

        // Show all other properties
        Object.entries(properties).forEach(([key, value]) => {
            if (!keyProps.includes(key) && key !== 'geometry') {
                const label = this.formatPropertyLabel(key);
                const formattedValue = this.formatPropertyValue(key, value);
                html += `
                    <div class="info-row">
                        <span class="info-label">${label}</span>
                        <span class="info-value">${formattedValue}</span>
                    </div>
                `;
            }
        });

        document.getElementById('info-content').innerHTML = html;
        document.getElementById('info-panel').classList.remove('hidden');
    }

    /**
     * Get key properties for a stage
     */
    getKeyProperties(stage) {
        const propMap = {
            'adoption_propensity': ['geo_code', 'adoption_propensity_score', 'home_charging_feasibility'],
            'charging_network': ['geo_code', 'accessibility_score', 'capacity_factor'],
            'trip_purpose': ['origin_code', 'destination_code', 'purpose', 'distance_km'],
            'range_feasibility': ['origin_code', 'destination_code', 'feasibility_category', 'distance_km'],
            'conversion_potential': ['geo_code', 'conversion_potential'],
            'ev_assignment_replaceable_only': ['geo_code', 'ev_type', 'two_seater_score', 'four_seater_score'],
            'integrated_conversion_with_ev_types': ['geo_code', 'integrated_score', 'deployment_priority']
        };
        return propMap[stage] || ['geo_code'];
    }

    /**
     * Format property label for display
     */
    formatPropertyLabel(prop) {
        return prop
            .replace(/_/g, ' ')
            .replace(/\b\w/g, l => l.toUpperCase());
    }

    /**
     * Format property value for display
     */
    formatPropertyValue(prop, value) {
        if (typeof value === 'number') {
            if (prop.includes('score') || prop.includes('potential') || prop.includes('feasibility')) {
                return value.toFixed(3);
            }
            if (prop.includes('distance') || prop.includes('km')) {
                return value.toFixed(1) + ' km';
            }
            return value.toLocaleString();
        }
        return value;
    }

    /**
     * Update legend based on current stage and active overlays
     */
    updateLegend() {
        const legendContainer = document.getElementById('legend');
        let html = '';

        // Add analysis layer legend if enabled
        if (this.showAnalysisLayer) {
            html += LAYERS.generateLegend(this.currentStage);
        }

        // Add overlay legends
        if (this.showCarAvailability) {
            if (html) html += '<hr class="legend-divider">';
            html += LAYERS.generateOverlayLegend('car_availability');
        }

        if (this.showEvDistribution) {
            if (html) html += '<hr class="legend-divider">';
            html += LAYERS.generateOverlayLegend('ev_distribution');
        }

        legendContainer.innerHTML = html || '<div class="legend-empty">No layers active</div>';
    }

    /**
     * Fly to selected region
     */
    flyToRegion() {
        if (this.currentRegion === 'all') {
            this.map.flyTo({
                center: CONFIG.map.center,
                zoom: CONFIG.map.zoom,
                duration: 1000
            });
        } else {
            const region = CONFIG.regions.find(r => r.id === this.currentRegion);
            if (region) {
                this.map.flyTo({
                    center: region.center,
                    zoom: region.zoom,
                    duration: 1000
                });
            }
        }
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.app = new EVModellingApp();
});
