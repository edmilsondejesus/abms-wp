model ABMSWPSimulacaoMensal

global {
    // Variáveis globais para contagem de residências
    int total_residencias <- 0;
    int total_ambientalistas <- 0;
    int total_perdularios <- 0;
    int total_moderados <- 0;
    int residencias_sem_consumo <- 0;
    list<string> matriculas_sem_consumo <- [];
    
    // Históricos para armazenamento temporal
    list<int> historico_total_residencias <- [];
    list<int> historico_ambientalistas <- [];
    list<int> historico_perdularios <- [];
    list<int> historico_moderados <- [];
    
    // Caminhos dos arquivos de dados
    string file_path <- "../includes/Tabela_consumidores_Itapua_com_setor_e_comportamento.csv";
    string consumo_file <- "../includes/Tabela_consumo_medio_Itapua_12m.csv";
    string shapefile_CD20220_path_prj <- "31984";
    file BA_setores_CD20220_shape_file <- shape_file("../includes/maps/Itapua13.shp", shapefile_CD20220_path_prj, true);
    
    // Variáveis de tempo e simulação
    int anos_simulacao <- 60;
    int currentYear <- 2025;
    int currentMonth <- 1;
    list<int> anos <- [2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032, 2033, 2034, 2035];
    
    // Taxas de crescimento
    list<float> taxas_crescimento_mensal <- [0.00025, 0.00023, 0.00020, 0.00018, 0.00016, 0.00014, 0.00012, 0.00009, 0.00007, 0.00004, 0.00001, -0.00001];
    
    // Dados de consumo por cenário
    list<float> consumo_anual_total_cI <- [];
    list<float> consumo_anual_total_cII <- [];
    list<float> consumo_anual_total_cIII <- [];
    
    // Variáveis para comunicação entre agentes
    list<float> dados_processados <- [];
    list<float> previsoes_consumo <- [];
    list<float> relatorio_final <- [];
    
    init {
        // Inicialização dos arquivos CSV
        csv_file arquivo <- csv_file(file_path, ";", true);
        csv_file arquivo_consumo <- csv_file(consumo_file, ";", true);
        
        // Criação dos agentes principais
        create Bairro from: BA_setores_CD20220_shape_file;
        create AnalyserAgent;
        create PredictorAgent;
        create CommunicationAgent;
        
        // Criação das residências
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
            
            // Tratamento de coordenadas
            if !(self["X"] = "" or self["Y"] = "") {
                latitude <- float(self["X"]);
                longitude <- float(self["Y"]);
                geometry gama_location <- to_GAMA_CRS({latitude, longitude});
                location <- point(gama_location);
            } else {
                location <- {0.0, 0.0};
            }
            
            // Inicialização do consumo
            list<ConsumoResidencia> consumos <- ConsumoResidencia where (each.sk_matricula = self.sk_matricula);
            
            if (empty(consumos)) {
                residencias_sem_consumo <- residencias_sem_consumo + 1;
                matriculas_sem_consumo << sk_matricula;
                
                float consumo_padrao <- 0.0;
                if (tp_comportamento = 'AMBIENTALISTA') {
                    consumo_padrao <- (52.621962 * nn_moradores * 30.5) / 1000;
                } else if (tp_comportamento = 'PERDULARIO') {
                    consumo_padrao <- (510.352010 * nn_moradores * 30.5) / 1000;
                } else {
                    consumo_padrao <- (144.315598 * nn_moradores * 30.5) / 1000;
                }
                
                consumo_atual_cI <- consumo_padrao;
                consumo_atual_cII <- consumo_padrao;
                consumo_atual_cIII <- consumo_padrao;
            } else {
                consumo_atual_cI <- consumos mean_of each.nn_consumo;
                consumo_atual_cII <- consumo_atual_cI;
                consumo_atual_cIII <- consumo_atual_cI;
            }
        }
    }
    
    reflex contar_residencias {
        total_residencias <- 0;
        total_ambientalistas <- 0;
        total_perdularios <- 0;
        total_moderados <- 0;

        ask Residencia {
            total_residencias <- total_residencias + 1;

            if (tp_comportamento = 'AMBIENTALISTA') {
                total_ambientalistas <- total_ambientalistas + 1;
            } else if (tp_comportamento = 'PERDULARIO') {
                total_perdularios <- total_perdularios + 1;
            } else {
                total_moderados <- total_moderados + 1;
            }
        }

        historico_total_residencias << total_residencias;
        historico_ambientalistas << total_ambientalistas;
        historico_perdularios << total_perdularios;
        historico_moderados << total_moderados;
    }
    

    reflex calcular_consumo_mensal {    
        string mes_ano <- string(currentMonth) + "/" + string(currentYear);
        write "Mês/Ano: " + mes_ano;
        
        consumo_anual_total_cI << Residencia sum_of each.consumo_atual_cI;
        consumo_anual_total_cII << Residencia sum_of each.consumo_atual_cII;
        consumo_anual_total_cIII << Residencia sum_of each.consumo_atual_cIII;

        write "Consumo previsto CI (" + mes_ano + "): " + consumo_anual_total_cI[cycle];
        write "Consumo previsto CII (" + mes_ano + "): " + consumo_anual_total_cII[cycle];
        write "Consumo previsto CIII (" + mes_ano + "): " + consumo_anual_total_cIII[cycle];
        
        // Atualização do tempo
        currentMonth <- currentMonth + 1;
        if (currentMonth > 12) {
            currentMonth <- 1;
            currentYear <- currentYear + 1;
        }
    }
    
    reflex stop_simulation when: currentYear = 2035 {
        do pause;
    }

	reflex coordenar_agentes {
        // Fluxo principal de execução dos agentes
        ask AnalyserAgent {
            do coletar_dados;
            do processar_dados;
        }
        
        // Passando dados_processados para PredictorAgent
        list<float> dados_para_predictor <- dados_processados;
        ask PredictorAgent {
            dados_recebidos <- dados_para_predictor;
            do calcular_previsao;
        }
        
        // Passando previsoes_consumo para CommunicationAgent
        list<float> dados_para_comm <- previsoes_consumo;
        ask CommunicationAgent {
            dados_relatorio <- dados_para_comm;
            do gerar_relatorio;
        }
    }
    
}



species AnalyserAgent {
    list<float> dados_coletados;
    
    action coletar_dados {
        dados_coletados <- Residencia collect each.consumo_atual_cI;
        write "AnalyserAgent: Dados coletados de " + length(dados_coletados) + " residências";
    }
    
    action processar_dados {
        float media <- mean(dados_coletados);
        float desvio <- standard_deviation(dados_coletados);
        
        // Processa e armazena diretamente na variável global
        dados_processados <- dados_coletados where (each < (media + 3 * desvio) and each > (media - 3 * desvio));
        
        write "AnalyserAgent: Dados processados (média: " + media + ", desvio: " + desvio + ")";
    }
}

species PredictorAgent {
    list<float> dados_recebidos;
    list<float> previsoes;
    
    action calcular_previsao {
        if (!empty(dados_recebidos)) {
            float ultimo_valor <- dados_recebidos[length(dados_recebidos) - 1];
            int indice_ano <- currentYear - 2025;
            float taxa <- taxas_crescimento_mensal[indice_ano min (length(taxas_crescimento_mensal) - 1)];
            float previsao <- ultimo_valor * (1 + taxa);
            
            previsoes << previsao;
            previsoes_consumo <- previsoes;
            
            write "PredictorAgent: Previsão calculada para " + currentMonth + "/" + currentYear + ": " + previsao;
        } else {
            write "PredictorAgent: Nenhum dado recebido para processamento";
        }
    }
}

species CommunicationAgent {
    list<float> dados_relatorio;
    
    action gerar_relatorio {
        if (!empty(dados_relatorio)) {
            float consumo_total <- sum(dados_relatorio);
            relatorio_final << consumo_total;
            
            float media <- mean(dados_relatorio);
            float maximo <- max(dados_relatorio);
            float minimo <- min(dados_relatorio);
            
            write "CommunicationAgent: Relatório gerado - Consumo total: " + consumo_total;
            write "Estatísticas - Média: " + media + ", Máximo: " + maximo + ", Mínimo: " + minimo;
        } else {
            write "CommunicationAgent: Nenhum dado recebido para relatório";
        }
    }
}

species ConsumoResidencia {
    string sk_matricula;
    int am_referencia;
    float nn_consumo;
}

species Residencia {
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
    
    float get_taxa_crescimento_mensal {
        int indice_ano <- currentYear - 2025;
        if (indice_ano >= 0 and indice_ano < length(taxas_crescimento_mensal)) {
            return taxas_crescimento_mensal[indice_ano];
        }
        return 0.0;
    }
    
    action atualizar_moradores {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        nn_moradores <- int(nn_moradores * (1 + taxa_mensal));
    }
    
    action prever_consumo {
        float taxa_mensal <- get_taxa_crescimento_mensal();
        
        // Cenário I: Todas as residências com ajuste
        consumo_atual_cI <- consumo_atual_cI * (1 + taxa_mensal);

        // Cenário II: Apenas ambientalistas com ajuste
        if (tp_comportamento = 'AMBIENTALISTA') {
            consumo_atual_cII <- consumo_atual_cII * (1 + taxa_mensal);
        }

        // Cenário III: Apenas perdulários com ajuste
        if (tp_comportamento = 'PERDULARIO') {
            consumo_atual_cIII <- consumo_atual_cIII * (1 + taxa_mensal);
        }
    }
    
    aspect base {
        if (latitude != 0.0 and longitude != 0.0) {
            if(tp_comportamento='AMBIENTALISTA') {
                draw circle(3) color: #green border: #green;
            } else if(tp_comportamento='MODERADO') {
                draw circle(3) color: #blue border: #blue;
            } else {
                draw circle(3) color: #red border: #red;
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
            chart "Monthly Consumption Forecast" type: series y_label: "Consumption (m^3)" x_label: "Month" {
                data "CI" value: consumo_anual_total_cI color: #blue;
                data "CII (environmentalist)" value: consumo_anual_total_cII color: #green;
                data "CIII (wasteful)" value: consumo_anual_total_cIII color: #red;
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
    output {
        monitor "Ano" value: anos[cycle];
        monitor "Consumo CI (m^3)" value: consumo_anual_total_cI[cycle];
        monitor "Consumo CII (m^3)" value: consumo_anual_total_cII[cycle];
        monitor "Consumo CIII (m^3)" value: consumo_anual_total_cIII[cycle];
        monitor "Residências sem dados" value: residencias_sem_consumo color: #orange;
    }
}