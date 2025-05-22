model ABMSWPSimulacaoMensal

global {
	
    // Contadores de residências por tipo
    int total_residencias <- 0;
    int total_ambientalistas <- 0;
    int total_perdularios <- 0;
    int total_moderados <- 0;
    
    int residencias_sem_consumo <- 0; // Contador de residências sem dados de consumo
    list<string> matriculas_sem_consumo <- []; // Lista de matriculas sem dados
    

    // Listas para armazenar contagens ao longo do tempo (opcional)
    list<int> historico_total_residencias <- [];
    list<int> historico_ambientalistas <- [];
    list<int> historico_perdularios <- [];
    list<int> historico_moderados <- [];
    
    // Caminho do arquivo CSV
    //string file_path <- "../includes/Tabela_consumidores_Itapua_convertida.csv";
    string file_path <- "../includes/Tabela_consumidores_Itapua_com_setor_e_comportamento.csv";

    string consumo_file <- "../includes/Tabela_consumo_medio_Itapua_12m.csv";
    
    string shapefile_CD20220_path_prj <- "31984";
	file BA_setores_CD20220_shape_file <- shape_file("../includes/maps/Itapua13.shp", shapefile_CD20220_path_prj, true);

    // Lendo os arquivos CSV
    csv_file arquivo <- csv_file(file_path, ";", true);
    csv_file arquivo_consumo <- csv_file(consumo_file, ";", true);
    
    // Caminho do arquivo Shapefile
    string shapefile_path <- "../includes/maps/LIMITE_BAIRRO.shp";
	
	//string shapefile_path <- "../includes/maps/Itapua_Setores_2022.shp";
    string shapefile_path_prj <- "31984";
    file shapefile <- shape_file(shapefile_path, shapefile_path_prj, true);
    //geometry shape <- envelope(shapefile);
    geometry shape <- envelope(BA_setores_CD20220_shape_file);
    
    // Variáveis globais para simulação
    int anos_simulacao <- 60; // Simulação por 60 meses
    int tempo_maximo <- anos_simulacao; // Tempo máximo em anos
    
    // Lista de taxas de crescimento anual para os próximos 10 anos
    list<float> taxas_crescimento_anual <- [0.0027, 0.0025, 0.0022, 0.0019, 0.0017, 0.0014, 0.0011, 0.0008, 0.0005, 0.0002];
     // Lista de taxas de crescimento mensal para cada um dos próximos 10 naos (média geométrica)
    list<float> taxas_crescimento_mensal <- [0.00025, 0.00023, 0.00020, 0.00018, 0.00016, 0.00014, 0.00012, 0.00009, 0.00007, 0.00004, 0.00001, -0.00001];
    
    // Lista para armazenar o consumo anual total
    list<float> consumo_anual_total_cI <- [];
    list<float> consumo_anual_total_cII <- [];
    list<float> consumo_anual_total_cIII <- [];
    
    // Variáveis para controlar ano e mês
	int currentYear <- 2025;
	int currentMonth <- 1;
	
    // Lista para armazenar os anos (2025 a 2034)
    list<int> anos <- [2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035];
    
    
  reflex contar_residencias {
    // Reinicia os contadores a cada passo
    total_residencias <- 0;
    total_ambientalistas <- 0;
    total_perdularios <- 0;
    total_moderados <- 0;

    // Conta as residências por tipo
    ask Residencia {
        total_residencias <- total_residencias + 1;

        if (tp_comportamento = 'AMBIENTALISTA') {
            total_ambientalistas <- total_ambientalistas + 1;
        } else if (tp_comportamento = 'PERDULARIO') {
            total_perdularios <- total_perdularios + 1;
        } else {
            total_moderados <- total_moderados + 1; // Assume-se que o resto é 'MODERADO'
        }
    }

    // Armazena no histórico (opcional)
    historico_total_residencias << total_residencias;
    historico_ambientalistas << total_ambientalistas;
    historico_perdularios << total_perdularios;
    historico_moderados << total_moderados;

    // Exibe no console (opcional)
    write "Total de Residências: " + total_residencias;
    write "Ambientalistas: " + total_ambientalistas;
    write "Perdulários: " + total_perdularios;
    write "Moderados: " + total_moderados;
}

     // Condição de parada: parar em 2034
    reflex stop_simulation when: currentYear = 2035 {
        do pause ;
    } 
    init {
        // Criando agentes a partir dos dados
        //create Bairro from: shapefile;
        create Bairro from: BA_setores_CD20220_shape_file;
        
        create ConsumoResidencia from: arquivo_consumo {
            sk_matricula <- string(self["SK_MATRICULA"]);
            am_referencia <- int(self["AM_REFERENCIA"]);
            nn_consumo <- float(self["HCLQTCON"]);
        }
        
        create Residencia from: arquivo {
            sk_matricula <- string(self["SK_MATRICULA"]);
            nm_subcategoria <- self["NM_SUBCATEGORIA"];
            tp_comportamento <- self["TP_COMPORTAMENTO"];
            nn_moradores <- int(self["NN_MORADORES"]);
            st_piscina <- int(self["ST_PISCINA"]);
            
            // Verificando se as coordenadas não estão vazias antes de converter
            if !(self["X"] = "" or self["Y"] = "") {
                latitude <- float(self["X"]);
                longitude <- float(self["Y"]);
                
                // Converter coordenadas UTM para o sistema de coordenadas do GAMA
                geometry gama_location <- to_GAMA_CRS({latitude, longitude});
                location <- point(gama_location);
            } else {
                // Se as coordenadas estiverem vazias, defina valores padrão ou ignore
                location <- {0.0, 0.0};
            }
            
            // Inicializa o consumo anual com base na média dos últimos 12 meses
            list<ConsumoResidencia> consumos <- ConsumoResidencia where (each.sk_matricula = self.sk_matricula);
            
            if (empty(consumos)) {
            	// Se não houver dados de consumo
            	residencias_sem_consumo <- residencias_sem_consumo + 1;
            	matriculas_sem_consumo << sk_matricula;
            
            	// Define um valor padrão baseado no comportamento
            	float consumo_padrao <- 0.0;
            	if (tp_comportamento = 'AMBIENTALISTA') {
                	consumo_padrao <- (52.621962 * nn_moradores * 30.5) / 1000; // Valor padrão para ambientalistas
            	} else if (tp_comportamento = 'PERDULARIO') {
                	consumo_padrao <- (510.352010 * nn_moradores * 30.5) / 1000; // Valor padrão para perdulários
            	} else {
               		consumo_padrao <- (144.315598 * nn_moradores * 30.5) / 1000; // Valor padrão para moderados
            	}
            
            	consumo_atual_cI <- consumo_padrao;
           	 	consumo_atual_cII <- consumo_padrao;
            	consumo_atual_cIII <- consumo_padrao;
            
           	 	//write "Aviso: Residência " + sk_matricula + " sem dados de consumo. Usando valor padrão: " + consumo_padrao;
        	} else {
          	  // Se houver dados de consumo, calcula a média normalmente
            	consumo_atual_cI <- consumos mean_of each.nn_consumo;
            	consumo_atual_cII <- consumo_atual_cI;
        	    consumo_atual_cIII <- consumo_atual_cI;
    	    }
 	       
        }
    }
    
    // Reflexo para calcular o consumo mensal total de todas as residências somadas.
    
    reflex prever_consumo_residencias {
    	ask Residencia {
        	do prever_consumo;
    	}
	}
    reflex calcular_consumo_mensal {    
   
    	// Exibe o ano e mês atual (opcional)
    	string mes_ano;
    	mes_ano <- string(currentMonth) + "/" + string(currentYear);
      	write "Mês/Ano: " + mes_ano;
       // Soma o consumo anual de todas as residências
        float consumo_total_cI <- Residencia sum_of each.consumo_atual_cI;
        float consumo_total_cII <- Residencia sum_of each.consumo_atual_cII;
        float consumo_total_cIII <- Residencia sum_of each.consumo_atual_cIII;
        
        // Adiciona o consumo total à lista de consumo anual
        consumo_anual_total_cI << consumo_total_cI ;// 1000;
        consumo_anual_total_cII << consumo_total_cII ;// 1000;
        consumo_anual_total_cIII << consumo_total_cIII ;// 1000;

        //write consumo_total;
        write "Consumo previsto CI (" + mes_ano + "): " + consumo_anual_total_cI[cycle];
        write "Consumo previsto CII (" + mes_ano + "): " + consumo_anual_total_cII[cycle];
        write "Consumo previsto CIII (" + mes_ano + "): " + consumo_anual_total_cIII[cycle];
        
    	// Atualiza o mês e ano
    	currentMonth <- currentMonth + 1;
    	if (currentMonth > 12) {
        	currentMonth <- 1;
        	currentYear <- currentYear + 1;
    	}
    	
    }
}

species ConsumoResidencia {
    // Atributos do agente
    string sk_matricula;
    int am_referencia;
    float nn_consumo;
}

species Residencia {
    // Atributos do agente
    string sk_matricula;
    string nm_subcategoria;
    int nn_moradores;
    int st_piscina;
    string tp_comportamento;
    float latitude;  
    float longitude;  
    float consumo_atual_cI;  
    float consumo_atual_cII; 
    float consumo_atual_cIII;
    
    // Função para obter a taxa de crescimento mensal com base no ciclo
	float get_taxa_crescimento_mensal {
    	// Calcula o índice baseado no ano atual (considerando que começamos em 2025)
    	int indice_ano <- currentYear - 2025;
    
    	// Verifica se o índice está dentro dos limites da lista
    	if (indice_ano >= 0 and indice_ano < length(taxas_crescimento_mensal)) {
        	return taxas_crescimento_mensal[indice_ano];
    	} else {
        	return 0.0; // Taxa zero após o último ano com taxa definida
    	}
	}
    
    
    // Atualiza o número de moradores com base na taxa de crescimento populacional
    action atualizar_moradores {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        nn_moradores <- int(nn_moradores * (1 + taxa_mensal));
    }
    
    // Calcula o consumo para os cenários I e II
    action prever_consumo {
    	//recupera a taxa de crescimento mensal
    	float taxa_mensal <- get_taxa_crescimento_mensal();
    
		// Cenário I: Todas as residências têm consumo ajustado pela taxa
        consumo_atual_cI <- consumo_atual_cI * (1 + taxa_mensal);

        // Cenário II: 
        // - Ambientalistas têm consumo ajustado pela taxa
        // - Outros mantêm o consumo atual (sem taxa)
        if (tp_comportamento = 'AMBIENTALISTA') {
            consumo_atual_cII <- consumo_atual_cII * (1 + taxa_mensal);
        } else {
            consumo_atual_cII <- consumo_atual_cII; // Mantém o valor atual (sem crescimento)
        }

        // Cenário III:
        // - Perdulários têm consumo ajustado pela taxa
        // - Outros mantêm o consumo atual (sem taxa)
        if (tp_comportamento = 'PERDULARIO') {
            consumo_atual_cIII <- consumo_atual_cIII * (1 + taxa_mensal);
        } else {
            consumo_atual_cIII <- consumo_atual_cIII; // Mantém o valor atual (sem crescimento)
        }
                
        //float fator_subcategoria <- (nm_subcategoria = "NORMAL") ? 1.0 : 1.05;
        //float fator_piscina <- (st_piscina = 1) ? 1.1 : 1.0;
        //consumo_atual_cII <- (consumo_atual_cII * (1 + taxa_mensal)) * fator_subcategoria * fator_piscina;
    }
    
    aspect base {
       if (latitude != 0.0 and longitude != 0.0) {
        	if(tp_comportamento='AMBIENTALISTA'){
        		 draw circle(3) color: #green border: #green;
        	}else{
        		 if(tp_comportamento='MODERADO'){
        		 	draw circle(3) color: #green border: #blue;
        			}else{
        				//Perdulário
        		 	draw circle(3) color: #red border: #red;	
        		}	
        	}	
        }        	
    }
}

species Bairro {
    aspect geom {
        draw shape color: #gray border: #black;
    }
}

experiment "Visualizacao" type: gui {
    output {
        display "Mapa" type: opengl {
            species Bairro aspect: geom;
            species Residencia aspect: base;
        }
        
        display "Graficos" type: java2D {
            chart "Monthly Consumption Forecast - 10 years" type: series y_label: "Consumption (m^3)" x_label: "Month" {
                data "CI" value: consumo_anual_total_cI color: #blue ;
                data "CII (environmentalist)" value: consumo_anual_total_cII color: #green ;
                data "CIII (wasteful)" value: consumo_anual_total_cIII color: #red ;

                
            }
        }   
        
        monitor "Total Residências" value: total_residencias;
        monitor "Ambientalistas" value: total_ambientalistas color: #green;
        monitor "Perdulários" value: total_perdularios color: #red;
        monitor "Moderados" value: total_moderados color: #blue;    
        monitor "Residências sem dados" value: residencias_sem_consumo color: #orange;
    }
}


experiment "Simulacao" type: batch {
    int tempo_maximo <- anos_simulacao; // Tempo máximo em anos
    output {
        monitor "Ano" value: anos[cycle]; // Exibe o ano atual (2025 a 2034)
        monitor "Consumo CI (m^3)" value: consumo_anual_total_cI[cycle]; // Usa o valor da lista consumo_anual_total
        monitor "Consumo CII (m^3)" value: consumo_anual_total_cII[cycle]; // Usa o valor da lista consumo_anual_total
        monitor "Consumo CIII (m^3)" value: consumo_anual_total_cIII[cycle]; // Usa o valor da lista consumo_anual_total
        monitor "Residências sem dados" value: residencias_sem_consumo color: #orange;

    }
}

