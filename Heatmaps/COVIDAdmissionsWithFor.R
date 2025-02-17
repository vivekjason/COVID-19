rm(list=ls())

library(tidyverse)
library(curl)
library(readxl)
library(paletteer)
library(extrafont)
library(ragg)
library(lubridate)
library(scales)

theme_custom <- function() {
  theme_classic() %+replace%
    theme(plot.title.position="plot", plot.caption.position="plot",
          strip.background=element_blank(), strip.text=element_text(face="bold", size=rel(1)),
          plot.title=element_text(face="bold", size=rel(1.5), hjust=0,
                                  margin=margin(0,0,5.5,0)),
          text=element_text(family="Lato"))
}

#Download latest primary diagnosis data
source <- "https://www.england.nhs.uk/statistics/wp-content/uploads/sites/2/2021/12/Primary-Diagnosis-Supplement-20211216.xlsx"
temp <- tempfile()
temp <- curl_download(url=source, destfile=temp, quiet=FALSE, mode="wb")

newdata_with <- read_excel(temp, sheet=1, range="C14:BZ22", col_names=FALSE) %>% 
  drop_na() %>% 
  gather(date, with, c(2:ncol(.))) %>% 
  rename("Region"=`...1`) %>% 
  mutate(date=as.Date("2021-10-01")+days(as.numeric(substr(date, 4, 6))-2))

newdata_from <- read_excel(temp, sheet=2, range="C14:BZ22", col_names=FALSE) %>% 
  drop_na() %>% 
  gather(date, from, c(2:ncol(.))) %>% 
  rename("Region"=`...1`) %>% 
  mutate(date=as.Date("2021-10-01")+days(as.numeric(substr(date, 4, 6))-2))

#download older data
source <- "https://www.england.nhs.uk/statistics/wp-content/uploads/sites/2/2021/12/Primary-Diagnosis-Supplement-20211209-20210618-20210930.xlsx"
temp <- tempfile()
temp <- curl_download(url=source, destfile=temp, quiet=FALSE, mode="wb")

olddata_with <- read_excel(temp, sheet=1, range="C14:DD22", col_names=FALSE) %>% 
  drop_na() %>% 
  gather(date, with, c(2:ncol(.))) %>% 
  rename("Region"=`...1`) %>% 
  mutate(date=as.Date("2021-06-18")+days(as.numeric(substr(date, 4, 6))-2))

olddata_from <- read_excel(temp, sheet=2, range="C14:DD22", col_names=FALSE) %>% 
  drop_na() %>% 
  gather(date, from, c(2:ncol(.))) %>% 
  rename("Region"=`...1`) %>% 
  mutate(date=as.Date("2021-06-18")+days(as.numeric(substr(date, 4, 6))-2))

data <- bind_rows(olddata_with, newdata_with) %>% 
  merge(bind_rows(olddata_from, newdata_from)) %>% 
  mutate(incidental=with-from) %>% 
  gather(type, count, c("with", "from", "incidental"))

agg_tiff("Outputs/COVIDAdmissionsCauseLondon.tiff", units="in", width=9, height=7, res=500)
ggplot(data %>% filter(Region=="London" & type!="with"), 
       aes(x=date, y=count, colour=type))+
  #geom_area(position="stack")+
  geom_line(show.legend=FALSE)+
  scale_x_date(name="")+
  scale_y_continuous(name="Number of patients", limits=c(0,NA))+
  scale_colour_paletteer_d("palettetown::porygon")+
  theme_custom()+
  theme(plot.subtitle=element_markdown())+
  labs(title="London's rising number of COVID patients are both 'with' and 'for' COVID",
       subtitle="Patients in London hospitals <span style='color:#40A0D8;'>due to COVID</span> and admissions <span style='color:#F89088;'>where COVID is not the primary cause of the admission</span>",
       caption="Data from NHS England | Plot by @VictimOfMaths")
dev.off()

agg_tiff("Outputs/COVIDAdmissionsCauseLondonStacked.tiff", units="in", width=9, height=7, res=500)
ggplot(data %>% filter(Region=="London" & type!="with"), 
       aes(x=date, y=count, fill=type))+
  geom_area(position="stack", show.legend=FALSE)+
  scale_x_date(name="")+
  scale_y_continuous(name="Number of patients", limits=c(0,NA))+
  scale_fill_paletteer_d("palettetown::porygon")+
  theme_custom()+
  theme(plot.subtitle=element_markdown())+
  labs(title="London's rising number of COVID patients are both 'with' and 'for' COVID",
       subtitle="Patients in London hospitals <span style='color:#40A0D8;'>due to COVID</span> and admissions <span style='color:#F89088;'>where COVID is not the primary cause of the admission</span>",
       caption="Data from NHS England | Plot by @VictimOfMaths")
dev.off()

agg_tiff("Outputs/COVIDAdmissionsCauseLondonProp.tiff", units="in", width=9, height=7, res=500)
data %>% filter(type!="incidental" & Region=="London") %>% 
  spread(type, count) %>% 
  mutate(prop=from/with) %>% 
  ggplot(aes(x=date, y=prop))+
  geom_line(colour="RoyalBlue")+
  scale_x_date(name="")+
  scale_y_continuous(name="Proportion of COVID patients for whom\nCOVID is the main cause of hospitalisation",
                     limits=c(0,NA), labels=label_percent(accuracy=1))+
  theme_custom()+
  labs(title="COVID remains the main reason people with COVID end up in hospital in London",
       subtitle="Proportion of total COVID-positive patients assessed to be in hospital 'for' rather than 'with' COVID in London NHS trusts",
       caption="Data from NHS England | Plot by @VictimOfMaths")
dev.off()

agg_tiff("Outputs/COVIDAdmissionsCausePropxReg.tiff", units="in", width=9, height=7, res=500)
data %>% filter(type!="incidental" & Region!="ENGLAND") %>% 
  spread(type, count) %>% 
  mutate(prop=from/with) %>% 
  ggplot(aes(x=date, y=prop, colour=Region))+
  geom_line()+
  scale_x_date(name="")+
  scale_y_continuous(name="Proportion of COVID patients for whom\nCOVID is the main cause of hospitalisation",
                     limits=c(0,NA), labels=label_percent(accuracy=1))+
  scale_colour_paletteer_d("colorblindr::OkabeIto")+
  theme_custom()+
  labs(title="The proportion of COVID patients hospitalised because of COVID varies a lot by region",
       subtitle="Proportion of total COVID-positive patients assessed to be in hospital 'for' rather than 'with' COVID by NHS region",
       caption="Data from NHS England | Plot by @VictimOfMaths")
dev.off()

