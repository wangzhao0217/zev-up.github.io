// Layer definitions and styling for MapLibre GL JS

const LAYERS = {
    /**
     * Generate PMTiles source URL
     */
    getSourceUrl(region, stage) {
        return `pmtiles://${CONFIG.pmtilesBaseUrl}/${region}_${stage}.pmtiles`;
    },

    /**
     * Generate PMTiles source URL for overlay layers
     */
    getOverlaySourceUrl(layerId) {
        return `pmtiles://${CONFIG.pmtilesBaseUrl}/${layerId}.pmtiles`;
    },

    /**
     * Get source layer name (matches the layer name in PMTiles)
     * Layer name was set to {region}_{stage} during tippecanoe conversion
     */
    getSourceLayer(region, stage) {
        return `${region}_${stage}`;
    },

    /**
     * Create polygon fill layer style
     */
    createPolygonFillStyle(sourceId, layerId, region, stage) {
        const stageConfig = CONFIG.stages.find(s => s.id === stage);
        const colorProperty = stageConfig.colorProperty;
        const colorScale = CONFIG.colorScales[stageConfig.colorScale];

        let fillColor;
        if (Array.isArray(colorScale)) {
            // Continuous scale (viridis, plasma)
            fillColor = [
                'interpolate',
                ['linear'],
                ['coalesce', ['get', colorProperty], 0],
                ...colorScale.flat()
            ];
        } else {
            // Categorical scale
            const matchExpr = ['match', ['get', colorProperty]];
            Object.entries(colorScale).forEach(([key, color]) => {
                matchExpr.push(key, color);
            });
            matchExpr.push('#95a5a6'); // default
            fillColor = matchExpr;
        }

        return {
            id: layerId,
            type: 'fill',
            source: sourceId,
            'source-layer': this.getSourceLayer(region, stage),
            paint: {
                'fill-color': fillColor,
                'fill-opacity': 0.7
            }
        };
    },

    /**
     * Create polygon fill layer style for overlay layers
     */
    createOverlayFillStyle(sourceId, layerId, overlayConfig) {
        const colorProperty = overlayConfig.colorProperty;
        const colorScale = CONFIG.colorScales[overlayConfig.colorScale];

        let fillColor;
        if (Array.isArray(colorScale)) {
            // Continuous scale (viridis, plasma)
            fillColor = [
                'interpolate',
                ['linear'],
                ['coalesce', ['get', colorProperty], 0],
                ...colorScale.flat()
            ];
        } else {
            // Categorical scale
            const matchExpr = ['match', ['get', colorProperty]];
            Object.entries(colorScale).forEach(([key, color]) => {
                matchExpr.push(key, color);
            });
            matchExpr.push('#95a5a6'); // default
            fillColor = matchExpr;
        }

        return {
            id: layerId,
            type: 'fill',
            source: sourceId,
            'source-layer': overlayConfig.sourceLayer,
            paint: {
                'fill-color': fillColor,
                'fill-opacity': 0.7
            }
        };
    },

    /**
     * Create polygon outline layer style for overlay layers
     */
    createOverlayOutlineStyle(sourceId, layerId, overlayConfig) {
        return {
            id: layerId + '-outline',
            type: 'line',
            source: sourceId,
            'source-layer': overlayConfig.sourceLayer,
            paint: {
                'line-color': '#ffffff',
                'line-width': 0.5,
                'line-opacity': 0.3
            }
        };
    },

    /**
     * Create polygon outline layer style
     */
    createPolygonOutlineStyle(sourceId, layerId, region, stage) {
        return {
            id: layerId + '-outline',
            type: 'line',
            source: sourceId,
            'source-layer': this.getSourceLayer(region, stage),
            paint: {
                'line-color': '#ffffff',
                'line-width': 0.5,
                'line-opacity': 0.5
            }
        };
    },

    /**
     * Create line layer style
     */
    createLineStyle(sourceId, layerId, region, stage) {
        const stageConfig = CONFIG.stages.find(s => s.id === stage);
        const colorProperty = stageConfig.colorProperty;
        const colorScale = CONFIG.colorScales[stageConfig.colorScale];

        let lineColor;
        if (typeof colorScale === 'object' && !Array.isArray(colorScale)) {
            // Categorical scale
            const matchExpr = ['match', ['get', colorProperty]];
            Object.entries(colorScale).forEach(([key, color]) => {
                matchExpr.push(key, color);
            });
            matchExpr.push('#95a5a6'); // default
            lineColor = matchExpr;
        } else {
            lineColor = '#3498db'; // fallback
        }

        return {
            id: layerId,
            type: 'line',
            source: sourceId,
            'source-layer': this.getSourceLayer(region, stage),
            paint: {
                'line-color': lineColor,
                'line-width': [
                    'interpolate',
                    ['linear'],
                    ['zoom'],
                    8, 1,
                    14, 3
                ],
                'line-opacity': 0.8
            }
        };
    },

    /**
     * Add a layer to the map
     */
    addLayer(map, region, stage) {
        const sourceId = `${region}-${stage}-source`;
        const layerId = `${region}-${stage}`;
        const stageConfig = CONFIG.stages.find(s => s.id === stage);

        // Add PMTiles source if not exists
        if (!map.getSource(sourceId)) {
            map.addSource(sourceId, {
                type: 'vector',
                url: this.getSourceUrl(region, stage)
            });
        }

        // Add layer based on type
        if (stageConfig.type === 'polygon') {
            if (!map.getLayer(layerId)) {
                map.addLayer(this.createPolygonFillStyle(sourceId, layerId, region, stage));
                map.addLayer(this.createPolygonOutlineStyle(sourceId, layerId, region, stage));
            }
        } else if (stageConfig.type === 'line') {
            if (!map.getLayer(layerId)) {
                map.addLayer(this.createLineStyle(sourceId, layerId, region, stage));
            }
        }

        return layerId;
    },

    /**
     * Remove a layer from the map
     */
    removeLayer(map, region, stage) {
        const sourceId = `${region}-${stage}-source`;
        const layerId = `${region}-${stage}`;

        // Remove layers
        if (map.getLayer(layerId)) {
            map.removeLayer(layerId);
        }
        if (map.getLayer(layerId + '-outline')) {
            map.removeLayer(layerId + '-outline');
        }

        // Remove source
        if (map.getSource(sourceId)) {
            map.removeSource(sourceId);
        }
    },

    /**
     * Generate legend HTML for a stage
     */
    generateLegend(stage) {
        const stageConfig = CONFIG.stages.find(s => s.id === stage);
        const colorScale = CONFIG.colorScales[stageConfig.colorScale];

        let html = `<div class="legend-title">${stageConfig.legendTitle}</div>`;

        if (Array.isArray(colorScale)) {
            // Gradient legend for continuous scales
            const colors = colorScale.map(([_, color]) => color).join(', ');
            html += `
                <div class="legend-gradient" style="background: linear-gradient(to right, ${colors});"></div>
                <div class="legend-labels">
                    <span>0</span>
                    <span>0.5</span>
                    <span>1</span>
                </div>
            `;
        } else {
            // Categorical legend
            Object.entries(colorScale).forEach(([label, color]) => {
                const displayLabel = label.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                html += `
                    <div class="legend-item">
                        <div class="legend-color" style="background: ${color};"></div>
                        <span>${displayLabel}</span>
                    </div>
                `;
            });
        }

        return html;
    },

    /**
     * Add an overlay layer to the map
     */
    addOverlayLayer(map, overlayId) {
        const overlayConfig = CONFIG.overlayLayers.find(o => o.id === overlayId);
        if (!overlayConfig) return null;

        const sourceId = `${overlayId}-source`;
        const layerId = overlayId;

        // Add PMTiles source if not exists
        if (!map.getSource(sourceId)) {
            map.addSource(sourceId, {
                type: 'vector',
                url: this.getOverlaySourceUrl(overlayId)
            });
        }

        // Add layer based on type
        if (overlayConfig.type === 'polygon') {
            if (!map.getLayer(layerId)) {
                map.addLayer(this.createOverlayFillStyle(sourceId, layerId, overlayConfig));
                map.addLayer(this.createOverlayOutlineStyle(sourceId, layerId, overlayConfig));
            }
        }

        return layerId;
    },

    /**
     * Remove an overlay layer from the map
     */
    removeOverlayLayer(map, overlayId) {
        const sourceId = `${overlayId}-source`;
        const layerId = overlayId;

        // Remove layers
        if (map.getLayer(layerId)) {
            map.removeLayer(layerId);
        }
        if (map.getLayer(layerId + '-outline')) {
            map.removeLayer(layerId + '-outline');
        }

        // Remove source
        if (map.getSource(sourceId)) {
            map.removeSource(sourceId);
        }
    },

    /**
     * Generate legend HTML for an overlay layer
     */
    generateOverlayLegend(overlayId) {
        const overlayConfig = CONFIG.overlayLayers.find(o => o.id === overlayId);
        if (!overlayConfig) return '';

        const colorScale = CONFIG.colorScales[overlayConfig.colorScale];

        let html = `<div class="legend-title">${overlayConfig.legendTitle}</div>`;

        if (Array.isArray(colorScale)) {
            // Gradient legend for continuous scales
            const colors = colorScale.map(([_, color]) => color).join(', ');
            // Adjust labels based on the data type
            let minLabel = '0';
            let midLabel = '0.5';
            let maxLabel = '1';

            if (overlayId === 'ev_distribution') {
                minLabel = '0';
                midLabel = '3000';
                maxLabel = '7000+';
            } else if (overlayId === 'car_availability') {
                minLabel = '0%';
                midLabel = '50%';
                maxLabel = '100%';
            }

            html += `
                <div class="legend-gradient" style="background: linear-gradient(to right, ${colors});"></div>
                <div class="legend-labels">
                    <span>${minLabel}</span>
                    <span>${midLabel}</span>
                    <span>${maxLabel}</span>
                </div>
            `;
        } else {
            // Categorical legend
            Object.entries(colorScale).forEach(([label, color]) => {
                const displayLabel = label.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
                html += `
                    <div class="legend-item">
                        <div class="legend-color" style="background: ${color};"></div>
                        <span>${displayLabel}</span>
                    </div>
                `;
            });
        }

        return html;
    }
};
