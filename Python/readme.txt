The input files required to run the simulations on the GAMA Platform are:

/includes/Tabela_consumo_Itapua_60m.csv - Contains the individual consumption of households over the last 60 months.

/includes/maps/Itapua13.shp - Contains the shapefile with the Census Sectors of the Iapuã Neighborhood

/includes/maps/LIMITE_BAIRRO.shp - Contains the shapefile of the city of Salvador, with the division of neighborhoods.

Then, the Python scripts below, present in the Python folder, must be executed, following the order in which they appear:

1 - Script_calcula_media_consumo.ipynb - Calculates the average consumption of homes, based on the last 12 months of consumption, generating the output file Tabela_consumo_medio_Itapua_12m.csv
2 - Script_mapeia_setor_censitario.ipynb - identifies the census sector of each consumer unit, generating the output file include\Tabela_consumidores_Itapua_com_setor.csv with a new column CD_SETOR
3 - Script_classifica_comportamento.ipynb - Classifies the behavior of each consumer unit, based on the average consumption of the last 12 months, generating the output file \includes\Tabela_consumidores_Itapua_com_setor_e_comportamento.csv with a new column TP_COMPORTAMENTO
4 - Script_total_de_ligacoes_por_setor.ipynb - calculates the total number of active connections per sector, generating the output file include\Table_top_10_setores.csv

After generating the complementary files, the ABMS-WP project must be opened in GAMA Platform and the simulations of the ABMS-WP_Simulacao_Mensal.gaml model run

The generated data can then be saved in a csv file, named resultados\dados_simulacao.csv

Then the Python Script below can be run to display the Simulation graph on an annualized scale.
Script_projecao_consumo_cenarios.ipynb - Contains the graphical display of the results of the forecasts generated in the simulation, with an annualized view.