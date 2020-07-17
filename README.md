# COVID-19 AND THE SCHOOLS: A STUDY CASE FROM BRAZIL


This project is part of a research that aims to generate an data-oriented agent-based model for the spread of the COVID-19 virus in the city of Lavras, Brazil. 

## Data

The data used to create the agents in this model (citizens of Lavras, and school classes) was extracted from a few sources, as shown below.

### IBGE Data

Data from [IBGE](https://www.ibge.gov.br) contains the biggest census and the data used refers to 2010, the last census ran in Brazil and documented. To access the data from Lavras, we filtered the Minas Gerais state data using the Code of Municipality of Lavras (3138203). The data collected is accessible in the link [downloads](https://www.ibge.gov.br/estatisticas/downloads-estatisticas.html). Navigate in the folders' tree until you find the following document:  

```
Censos -> Censo_Demografico_2010 -> Resultados_do_Universo -> Agregados_por_Setores_Censitarios -> MG_YYYYMMDD.zip
```

### INEP Data

INEP is the National Institute for Educational Research. They organize census from time to time to collect data about the schools in Brazil. They follow similar identation for the data collected as IBGE, sectorizing the samples by the same regions IBGE uses to get information from the population. For this work work we've used the [Census from 2018](http://portal.inep.gov.br/web/guest/microdados#). The data provided regards the whole country. So we filtered the data related only for the city of Lavras.


## How this repository is organized?

The repository you are accessing contains Jupyter Notebooks (under construction), data and NetLogo code.

### *code* folder

Code folder contains the Juputer Notebooks, the requirements for running the Python code, the *lib* folder containing Python libraries created to handle the data present in the *data* folder, and the *model* folder.

### The *model* folder 

The *model* folder is where the Netlogo code is. There you can find:

* **Schools.nlogo:** this is the main code for executing the simulations. We used BehaviorSpace to execute them multiple times with all the combinations of the variables chosen to be studied.
* **scenario.csv:** due to the long time to populate the model, we created a mechanism to export the generated population and the data containing the initial setup is saved in a file called *scenario.csv*. Everytime a new population is generated, this file is overwritten.
* **inputs:** this folder contains the summarized data that describe the **classes.csv** and the **students.csv**. These two spreadsheets are used to populate the model. There is also the **infection** folder where information over number of contacts and chances of infecting other people are presented.
* **outputs:** this folder is used to collect the results when the BehaviorSpace is ran headless. Here there will be spreadsheets containing the outcomes of the simulation that will be used for analysis later.

## Usage

### Netlogo simulations

The netlogo code can be run using the interface and BehaviorSpace experiment setups, or it can be executed headless. For more information on how to run it headless, [check this out](https://ccl.northwestern.edu/netlogo/docs/behaviorspace.html).

## QGIS

### Adding IBGE data from shapefile to the school dots

[Tutorial - Performing Spatial Joins](https://www.qgistutorials.com/en/docs/performing_spatial_joins.html)