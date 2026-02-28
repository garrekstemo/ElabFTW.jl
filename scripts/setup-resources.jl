# Setup eLabFTW resource categories and templates for Quantum Photo-Science Laboratory
#
# This script restructures the lab's eLabFTW resource types into a two-tier system:
#
#   Categories (lightweight labels on items):
#     - Sample — what you measured
#     - Instrument — what you measured with (Tier 1: bookable measurement systems,
#       Tier 2: reference catalog for components/equipment)
#     - Procedure — how to operate instruments
#
#   Templates (items_types with extra_fields):
#     - Sample template — Material, Substrate, Preparation Method, etc.
#     - Instrument template — Type, Manufacturer, Model, Location, etc.
#     - Procedure template — body text only
#
# eLabFTW has two separate concepts:
#   - resources_categories (at /teams/{id}/resources_categories/) — lightweight
#     name+color labels. This is what items reference via their `category` field.
#   - items_types (at /items_types/) — rich templates with body, metadata, and
#     extra_fields that define the default structure for new items.
#
# Usage:
#   julia --project=. scripts/setup-resources.jl
#
# Requires ELABFTW_URL and ELABFTW_API_KEY environment variables.
# API key must have admin privileges to create/rename/delete categories.

using ElabFTW
import ElabFTW: _elabftw_config, _elabftw_request, _elabftw_post, _elabftw_patch, _elabftw_delete
import JSON

if !elabftw_enabled()
    error("eLabFTW not configured. Set ELABFTW_URL and ELABFTW_API_KEY.")
end

println("Connected to $(_elabftw_config.url)\n")

# ============================================================================
# Configuration — adjust these for your eLabFTW instance
# ============================================================================

TEAM_ID = 26  # Quantum Photo-Science Laboratory

# ============================================================================
# Step 1: Set up resource categories (name + color labels)
# ============================================================================

println("=" ^ 60)
println("Step 1: Resource categories")
println("=" ^ 60)

cat_base = "$(_elabftw_config.url)/api/v2/teams/$TEAM_ID/resources_categories"

# List existing categories
resp = _elabftw_request(cat_base)
existing = JSON.parse(String(resp.body))
cat_names = Dict(c["title"] => c["id"] for c in existing)

println("Existing categories:")
for c in existing
    println("  ID=$(c["id"]): \"$(c["title"])\" color=$(c["color"])")
end

# Create or rename as needed
target_categories = [
    ("Sample",     "0077bb"),
    ("Instrument", "000000"),
    ("Procedure",  "008cb4"),
]

for (name, color) in target_categories
    if haskey(cat_names, name)
        println("  '$name' already exists (ID=$(cat_names[name]))")
    else
        println("  Creating '$name'...")
        resp = _elabftw_post(cat_base, Dict("name" => name, "color" => color))
        println("  Created")
    end
end

println()

# ============================================================================
# Step 2: Create resource templates with extra_fields
# ============================================================================

println("=" ^ 60)
println("Step 2: Resource templates (items_types)")
println("=" ^ 60)

# Check existing templates
templates = list_items_types(limit=100)
tmpl_names = Dict(t["title"] => t["id"] for t in templates)

# --- Sample template ---

samples_metadata = Dict(
    "extra_fields" => Dict(
        "Material" => Dict(
            "type" => "text", "value" => "",
            "description" => "e.g. WSe2, ZIF-62, NH4SCN/DMF 1.0M",
            "position" => 1
        ),
        "Substrate" => Dict(
            "type" => "text", "value" => "",
            "description" => "e.g. SiO2/Si, CaF2, quartz, cuvette",
            "position" => 2
        ),
        "Preparation Method" => Dict(
            "type" => "select", "value" => "",
            "options" => ["exfoliation", "spin-coat", "drop-cast",
                          "solution", "melt-quench", "CVD", "other"],
            "description" => "How the sample was prepared",
            "position" => 3
        ),
        "Prepared By" => Dict(
            "type" => "users", "value" => "",
            "description" => "Who prepared the sample",
            "position" => 4
        ),
        "Preparation Date" => Dict(
            "type" => "date", "value" => "",
            "position" => 5
        ),
        "Storage Location" => Dict(
            "type" => "text", "value" => "",
            "description" => "e.g. N2 glovebox shelf 2, desiccator A",
            "position" => 6
        ),
    ),
    "elabftw" => Dict("display_main_text" => true)
)

if haskey(tmpl_names, "Sample")
    println("  'Sample' template already exists (ID=$(tmpl_names["Sample"]))")
else
    id = create_items_type(title="Sample", metadata=samples_metadata)
    println("  Created 'Sample' template (ID=$id)")
end

# --- Instrument template ---

instruments_metadata = Dict(
    "extra_fields" => Dict(
        "Type" => Dict(
            "type" => "select", "value" => "",
            "options" => ["spectrometer", "laser", "detector",
                          "furnace", "cryostat", "optics", "other"],
            "description" => "Instrument category",
            "position" => 1
        ),
        "Manufacturer" => Dict(
            "type" => "text", "value" => "",
            "position" => 2
        ),
        "Model" => Dict(
            "type" => "text", "value" => "",
            "position" => 3
        ),
        "Serial Number" => Dict(
            "type" => "text", "value" => "",
            "position" => 4
        ),
        "Location" => Dict(
            "type" => "text", "value" => "",
            "description" => "Room number or lab area",
            "position" => 5
        ),
        "Last Calibration" => Dict(
            "type" => "date", "value" => "",
            "position" => 6
        ),
        "Manual / Docs" => Dict(
            "type" => "url", "value" => "",
            "description" => "Link to manual or documentation",
            "position" => 7
        ),
    ),
    "elabftw" => Dict("display_main_text" => true)
)

if haskey(tmpl_names, "Instrument")
    println("  'Instrument' template already exists (ID=$(tmpl_names["Instrument"]))")
else
    id = create_items_type(title="Instrument", metadata=instruments_metadata)
    println("  Created 'Instrument' template (ID=$id)")
end

# --- Procedure template ---

if haskey(tmpl_names, "Procedure")
    println("  'Procedure' template already exists (ID=$(tmpl_names["Procedure"]))")
else
    id = create_items_type(title="Procedure")
    println("  Created 'Procedure' template (ID=$id)")
end

println()

# ============================================================================
# Summary
# ============================================================================

println("=" ^ 60)
println("Setup complete")
println("=" ^ 60)
println()

resp = _elabftw_request(cat_base)
cats = JSON.parse(String(resp.body))
println("Resource categories:")
for c in cats
    println("  $(c["title"]) (ID=$(c["id"]), color=#$(c["color"]))")
end

println("\nResource templates:")
for t in list_items_types(limit=100)
    println("  $(t["title"]) (ID=$(t["id"]))")
end

println("\nItems:")
for it in list_items(limit=50)
    println("  $(it["id"]) | $(get(it, "category_title", "?")) | $(it["title"])")
end
