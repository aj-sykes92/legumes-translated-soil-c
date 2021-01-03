Legumes Translated Soil Carbon Modelling
================
Dr Alasdair Sykes
03/01/2021

## Overview

This repository contains inputs, code and outputs for soil carbon
modelling work performed to accompany the Legumes Translated project.
The model input data compares a set of control rotations to a series of
alternative legume-based rotations; model outputs detail expected soil
carbon stock change as a result of these different management
strategies. All code in the root directory is reproducible with the
contents of this repository; external data read-in is handled in the
`raw-data` directory.

## Model and data provenance

Soil carbon modelling is performed using an R package-based
implementation of the IPCC (2019) Tier 2 steady-state soil carbon model
for national level greenhouse gas reporting. Full details of the model
methodology can be found
[here](https://www.ipcc-nggip.iges.or.jp/public/2019rf/vol4.html);
documentation of the corresponding R package implementation can be found
[here](https://github.com/aj-sykes92/soilc.ipcc).

Spatial data used in the modelling process is (1) climate data from the
CRU project, available open-source here
[here](https://crudata.uea.ac.uk/cru/data/hrg/cru_ts_4.03/), and (2)
soil data from the SoilGrids project, available open-source
[here](https://soilgrids.org). Spatial definition of the study sites is
based on NUTS 2017 Level 2 data, with corresponding shapefiles available
[here](https://ec.europa.eu/eurostat/web/gisco/geodata/reference-data/administrative-units-statistical-units/nuts).

## Schema in brief

### Code

  - `01-spatial-data-processing.R` Processing of the study spatial data,
    resulting in study site-specific outputs of climate and soil data.

  - `02-model-data-assembly.R` Reading of the raw supplied data files
    and construction of the raw model data.

  - `03-model-input-processing.R` Conversion of the assembled raw data
    input model inputs and creation of the soil carbon model runs using
    the `soilc.ipcc` package.

  - `04-model-output-processing.R` Summarisation of the model outputs
    into summary datasets and plots.

### Subdirectories

  - **model-data** Data directory containing model input and output
    datasets.

  - **model-output-summaries** Data directory containing summarised
    model outputs.

  - **raw-data** Data directory containing raw spatial data, raw study
    data as supplied, and data translation scripts.

  - **spatial-data** Data directory containing processed spatial data.

## Contact

All queries relating to this work should be addressed to the author at
<alasdair.sykes@sruc.ac.uk>.
