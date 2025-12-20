# ZEV-UP Web Visualization

Interactive web map for visualizing Frugal EV Adoption Feasibility analysis across Scotland's regional transport partnerships.

**Live Site:** https://wangzhao0217.github.io/zev-up.github.io/

## Project Structure

```
web/
├── index.html                    # Main HTML page
├── css/
│   └── style.css                 # Styles (light theme)
├── js/
│   ├── config.js                 # Configuration (regions, stages, basemaps, available files)
│   ├── layers.js                 # PMTiles layer management
│   └── app.js                    # Main application logic
├── pmtiles/                      # PMTiles data files
│   ├── zettrans_*.pmtiles        # ZetTrans region (all 7 stages)
│   └── hitrans_trip_purpose.pmtiles
└── scripts/
    └── convert_gpkg_to_pmtiles.R # R script for GPKG to PMTiles conversion
```

## Updating PMTiles Data

### Prerequisites

- R with `sf` and `dplyr` packages
- Tippecanoe (already installed in dev container)

### Step 1: Run the Conversion Script

```r
# From R console
source("/workspaces/EV_modelling/web/scripts/convert_gpkg_to_pmtiles.R")
convert_all()
```

This converts GPKG files from `output/{REGION}/` to PMTiles in `web/pmtiles/`.

**Input files per region:**
- `adoption_propensity.gpkg` (columns 418-438)
- `charging_network.gpkg` (columns 418-434)
- `trip_purpose.gpkg` (columns 15-25)
- `range_feasibility.gpkg` (columns 3-10)
- `conversion_potential.gpkg` (columns 418-439)
- `ev_assignment_replaceable_only.gpkg` (columns 418-451)
- `integrated_conversion_with_ev_types.gpkg` (columns 418-444)

**Output naming:** `{region}_{stage}.pmtiles` (e.g., `zettrans_adoption_propensity.pmtiles`)

### Step 2: Update Available Files in Config

Edit `js/config.js` and update the `availableFiles` array with the new PMTiles files:

```javascript
availableFiles: [
    'hitrans_trip_purpose',
    'zettrans_adoption_propensity',
    'zettrans_charging_network',
    // ... add new files here
],
```

### Step 3: Commit and Push

```bash
cd /workspaces/EV_modelling/web
git add pmtiles/*.pmtiles js/config.js
git commit -m "Update PMTiles data"
git push
```

## Updating the Website

### Making Changes

1. **Edit files** in the `web/` directory
2. **Test locally** (optional): Use a local server like `python -m http.server 8000`
3. **Commit and push:**

```bash
cd /workspaces/EV_modelling/web
git add -A
git commit -m "Description of changes"
git push
```

GitHub Pages will automatically rebuild (takes 1-2 minutes).

### Common Updates

#### Add a New Region

1. Run conversion script for the new region's GPKG files
2. Add PMTiles files to `web/pmtiles/`
3. Update `availableFiles` in `js/config.js`
4. Commit and push

#### Change Basemap Options

Edit `js/config.js` → `basemaps` object:

```javascript
basemaps: {
    'custom': {
        name: 'Custom Map',
        style: 'https://example.com/style.json'
    }
}
```

#### Modify Color Schemes

Edit `js/config.js` → `colorScales` object for data visualization colors.

Edit `css/style.css` for UI colors.

#### Update Column Ranges

If GPKG column structure changes, edit `scripts/convert_gpkg_to_pmtiles.R`:

```r
COLUMN_RANGES <- list(
  adoption_propensity = c(418, 438),
  # ... update ranges as needed
)
```

## Available Data

| Region | Stages Available |
|--------|------------------|
| ZetTrans | All 7 stages |
| HITRANS | Trip Purpose only |
| Others | Not yet converted |

## Analysis Stages

1. **Adoption Propensity** - Demographic-based EV adoption likelihood
2. **Charging Network** - Charging infrastructure accessibility
3. **Trip Purpose** - Trip purpose suitability analysis
4. **Range Feasibility** - 100km range constraint analysis
5. **Conversion Potential** - Trip conversion potential
6. **EV Assignment** - 2-seater vs 4-seater assignment
7. **Integrated Analysis** - Final integrated feasibility

## Troubleshooting

### Layers not loading

1. Check browser console (F12) for errors
2. Verify PMTiles files exist in `pmtiles/` folder
3. Ensure `availableFiles` in config.js includes the file
4. Hard refresh browser: `Ctrl+Shift+R`

### CORS errors

PMTiles must be served from the same origin. Files committed to the repo and served via GitHub Pages will work. GitHub Releases URLs do not support CORS.

### Large file warnings

GitHub warns about files >50MB. Consider:
- Increasing simplification in the R script
- Sampling large line datasets more aggressively
- Using Git LFS for very large files

## Technology Stack

- **MapLibre GL JS** - Map rendering
- **PMTiles** - Efficient vector tile format
- **Tippecanoe** - GPKG/GeoJSON to PMTiles conversion
- **GitHub Pages** - Static site hosting
