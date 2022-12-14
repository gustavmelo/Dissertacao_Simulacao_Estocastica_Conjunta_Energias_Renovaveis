library(readxl)
library(openxlsx)

####Leitura do arquivo##########################################################

setwd("C:/arquivos/Mestrado/Dissertacao/Codigos/Usina_Assu_SClara/Dados/") #alterar diret?rio para seu endere?o

#ATEN??O: Manter sempre a estrutura dos arquivos 

#Alterar de acordo com usina
dorig = readxl::read_xlsx(path = "DadosSem2022.xlsx") 

#### Modelagem ###############################################################

i = 1
centroides<-list()
clusters<-list()
dorig$cluster<-''
dorig$cl_GE<-''
dorig$cl_GS<-''

start.time<-Sys.time()

for (m in 1:12){
  for (h in 0:23){
    clusterizacao <- clusterizar(dorig, m, h) #fun??o para clusteriza??o
    centroides[i]<-list(clusterizacao[1])
    clusters[i]<-list(clusterizacao[2])
    
    ctr<-data.frame(centroides[i]) #grava centroides dos clusters da hora h, mes m
    cl<-data.frame(clusters[i]) #grava clusteriza??o da hora h, mes m
    for (j in 1:nrow(cl)) {
      dorig$cluster[which((dorig$Mes == m)&(dorig$Hora == h))][[j]]<-cl[[1]][[j]]
      dorig$cl_GE[which((dorig$Mes == m)&(dorig$Hora == h))][[j]]<-ctr[[1]][[cl[[1]][[j]]]]
      dorig$cl_GS[which((dorig$Mes == m)&(dorig$Hora == h))][[j]]<-ctr[[2]][[cl[[1]][[j]]]]
    }
    i = i + 1 
  }
}

end.time<-Sys.time()
time.taken<-end.time-start.time
time.taken

#write.table(dorig, file='Clusterizacao.csv', sep=';', dec=',')

####Cria??o do vetor inicial de probabilidades incondicionais (m?s 1, hora 0) e das matrizes de transi??o####

#Vetor inicial de probabilidades incondicionais (m?s 1, hora 0)

cont<-vector()
tot=0

for (c in 1:nrow(centroides[[1]][[1]])){
  cont[c]<-nrow(dorig[which((dorig$Mes == 1)&(dorig$Hora == 0)&(dorig$cluster == c)),]) #Mes e Hora s?o o m?s e hor?rio iniciais dos cen?rios, editar se diferente de hora zero de janeiro
  tot=tot+cont[c]
}

cont=cont/tot
cont_acum<-cont

for(z in 2:length(cont)){
  cont_acum[z]<-cont_acum[z-1]+cont_acum[z]
}

#Matrizes de transi??o entre os hor?rios do mesmo m?s

aux=1
MT_ind_intra<-list()
MT_acum_intra<-list()

for (i in 1:288) { #24 matrizes de transi??o para cada m?s do ano
  if (aux!=24) {
    matr<-matriz_intra1(i) #fun??o para MT intraday (entre horas do mesmo dia)
    MT_ind_intra[i]<-list(matr[1])
    MT_acum_intra[i]<-list(matr[2])
    aux = aux + 1
  } else {
    matr<-matriz_intra2(i) #fun??o para interday (entre d e d+1, i.e., 23h (d) e 0h (d+1))
    MT_ind_intra[i]<-list(matr[1]) 
    MT_acum_intra[i]<-list(matr[2])
    aux = 1
  }
}

#Matrizes de transi??o entre os meses

diasmes <- c(31,28,31,30,31,30,31,31,30,31,30,31)
#num_anos <- max(dorig$Ano) - min(dorig$Ano) + 1
MT_ind_inter<-list()
MT_acum_inter<-list()

for (i in 1:11) { #11 matrizes de transi??o entre os 12 meses do ano
    matr<-matriz_inter(i) #fun??o para MT entre os meses 
    MT_ind_inter[i]<-list(matr[1])
    MT_acum_inter[i]<-list(matr[2])
}

###Salvando exemplos

#Obs.: na lista centroides, ?ndice usado refere-se ? hora anterior ao ?ndice 
Hora<-12 #0 a 23

#Considerar as duas vari?veis abaixo diferentes de 1 apenas quando os dados originais forem fator de capacidade. 
cap_inst_eol<-1 #capacidade instalada da usina (e?lica). 
cap_inst_sol<-1 #capacidade instalada da usina (solar)

for (Mes in 1:12){
  clustersh<-data.frame(centroides[[((Hora+1)+24*(Mes-1))]])
  clustersh[,1]<-clustersh[,1]*cap_inst_eol
  clustersh[,2]<-clustersh[,2]*cap_inst_sol
  write.xlsx(clustersh, paste0("Centroide_",Mes,"_",Hora,".xlsx"))  
}

#Na lista MT_acum_intra, ?ndice usado refere-se ? transi??o entre hora anterior e hora do ?ndice
matriz_ex <- data.frame(MT_acum_intra[126]) #5 e 6
write.table(matriz_ex, file='Mt_acum_intra_horas_5e6_mes6.csv', sep=';', dec=',')

#Exemplo entre os meses 1 e 2
write.table(data.frame(MT_acum_inter[1]), file='Mt_acum_inter_mes_1e2.csv', sep=';', dec=',')

#Exemplo vetor de prob. incondicional

write.table(cont_acum, file='Prob_incond_m1h0.csv', sep=';', dec=',')

###Salvando arquivos da modelagem

saveRDS(centroides, file="Centroides.RData")
saveRDS(clusters, file="Clusters_dados.RData")
saveRDS(dorig, file="Clusterizacao.RData")
saveRDS(cont, file="Prob_ind_incond.RData")
saveRDS(cont_acum, file="Prob_acum_incond.RData")
saveRDS(MT_acum_inter, file="MT_acum_inter.RData")
saveRDS(MT_acum_intra, file="MT_acum_intra.RData")
saveRDS(MT_ind_inter, file="MT_ind_inter.RData")
saveRDS(MT_ind_intra, file="MT_ind_intra.RData")
#listateste<-readRDS("MT_acum_inter.RData")

#### Simula??o de cen?rios #########################################################

estados_sim <- data.frame(Sim=integer(),
                          Mes=integer(),
                          Dia=integer(),
                          Hora=integer(),
                          Estado=integer(),
                          GE=double(),
                          GS=double(),
                          Uniforme=double())

i=1 #?ndice das linhas do df a serem preenchidas

start.time <- Sys.time()

for(cenario in 199:200) {
  for (mes in 1:12) {
    for (dia in 1:diasmes[mes]) {
      for (hora in 0:23) {
        
        estados_sim[i,1]=cenario
        estados_sim[i,2]=mes
        estados_sim[i,3]=dia
        estados_sim[i,4]=hora
        
        if(mes==1 && dia==1 && hora==0) { #primeiro valor da simula??o, i.e., 01/01, hora zero
          inicio<-estadoinicial(cont_acum) #fun??o para sortear estado inicial, considerando vetor de probabilidades incondicionais
          estado2<-inicio[[1]]
          estados_sim[i,8]<-inicio[[2]] #para registrar valor da uniforme simulado
        }else if(dia==1 && hora==0) { #primeira hora do m?s (exceto janeiro), MT deve ser intermensal
          MT <- data.frame(MT_acum_inter[mes-1])
          if(MT[estado1,1]=='NaN'){ 
            estado2<-novoestado_distmin(mes,estado1) #fun??o para verificar dist?ncia entre estado1 e cada estado candidato poss?vel e selecionar o de menor dist?ncia
          }else{
            simulado<-novoestado(estado1,MT) #fun??o para simular o pr?ximo estado
            estado2<-simulado[[1]]
            estados_sim[i,8]<-simulado[[2]] #para registrar valor da uniforme simulado
          }
        }else {
          if(hora==0) { #n?o ? primeiro dia, ent?o usa-se ?ltima MT do m?s (23 para 0, interdi?ria)
            MT <- data.frame(MT_acum_intra[24*mes]) 
          }else { #MT de ?ndice igual estado a ser simulado
            MT <- data.frame(MT_acum_intra[24*(mes-1)+hora]) 
          }
          simulado<-novoestado(estado1,MT) #fun??o para simular o pr?ximo estado
          estado2<-simulado[[1]]
          estados_sim[i,8]<-simulado[[2]] #para registrar valor da uniforme simulado
        }
        
        estado1=estado2
        estados_sim[i,5]=estado2
        estados_sim[i,6]=data.frame(centroides[24*(mes-1)+(hora+1)])[estado2,1]
        estados_sim[i,7]=data.frame(centroides[24*(mes-1)+(hora+1)])[estado2,2]
        i=i+1
        
      }
    }
  }
}

end.time <- Sys.time()
time.taken <- end.time - start.time
time.taken

write.csv(estados_sim, "Cenarios200.csv")
