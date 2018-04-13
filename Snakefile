
import pandas as pd
import os, sys, glob
import numpy as np
from pathlib import Path
import subprocess as sp
from shutil import copyfile

configfile: 'config.yaml'


sys.path.append(srcdir(".") + "/src/")
sys.path.append(srcdir(".") + "/Softwares/MACS/lib/python2.7/site-packages/")
from util_pipeline import get_paths
from util_pipeline import query_SRR

REFLIB = config['bwa']['reflib']
PATH_OUT = config['path']['output']
PATH_FASTQ = config['path']['fastq']
PATH_BAM = config['path']['bam']
PATH_LOG = config['path']['log']
PATH_QC = config['path']['qc']
PATH_PEAKS = config['path']['peaks']
PATH_SRATOOL = config['path']['sratools']
if PATH_SRATOOL[0] is not '/':
    PATH_SRATOOL = srcdir('.') + '/' + PATH_SRATOOL
PATH_EDIRECT = config['path']['edirect']
if PATH_EDIRECT[0] is not '/':
    PATH_EDIRECT = srcdir('.') + '/' + PATH_EDIRECT

PEAKCALLER = config['peakcalling']

if len(config['intersection']) > 1:
    PEAKCALLER = PEAKCALLER + ['peak.intersect']
    INTERSECT = config['intersection']

if len(config['intersection']) == 1:
    raise ValueError('Taking intersection is specified, but only one peak file is given.')

# adding paths for using MACS/DFILTER
os.environ["PATH"] = srcdir('.') + '/' + config['dfilter']['path']+":"+os.environ["PATH"]

# get IDs
DataTable = pd.read_csv('DataList.csv')
PeakCall = pd.read_csv('PeakPairs.csv')

GEOID = DataTable.loc[DataTable.Source=='GEO'].ID.tolist()
WZID_BAM = DataTable.loc[np.intersect1d(np.where(DataTable.Source=='forge'), np.where(DataTable.Format =='bam'))].ID.tolist()
WZID_FASTQ = DataTable.loc[np.intersect1d(np.where(DataTable.Source=='forge'), np.where(DataTable.Format =='fastq'))].ID.tolist()
Local_BAM = DataTable.loc[np.intersect1d(np.where(DataTable.Source=='local'), np.where(DataTable.Format == 'bam'))].ID.tolist()
Local_FASTQ = DataTable.loc[np.intersect1d(np.where(DataTable.Source=='local'), np.where(DataTable.Format == 'fastq'))].ID.tolist()

ALLID = GEOID + WZID_BAM + WZID_FASTQ + Local_BAM + Local_FASTQ
PEAKID = PeakCall.Signal.tolist()

PATH_DATA = DataTable.loc[DataTable.Source=='forge'].Path.value_counts().index.tolist()
PATH_LOCAL_BAM = dict()
for local in Local_BAM:
    PATH_LOCAL_BAM[local] = DataTable[DataTable.ID == local].Path.tolist()[0]

PATH_LOCAL_FASTQ = dict()
for local in Local_FASTQ:
    PATH_LOCAL_FASTQ[local] = glob.glob(DataTable[DataTable.ID == local].Path.tolist()[0] + local + '*.fastq.gz')[0]


rule all:
    input:
        expand(PATH_OUT + '{sample}.{format}', sample = PEAKID, format=PEAKCALLER),
        expand(PATH_OUT + '{sample}.tdf', sample = ALLID),
        expand(PATH_QC + '{sample}.phantom', sample = PEAKID)

include: 'src/alignment.smk'
include: 'src/peakcalling.smk'
include: 'src/QC.smk'
