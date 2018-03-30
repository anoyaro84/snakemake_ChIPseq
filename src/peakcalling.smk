
rule index_bam:
    message:
        "indexing bam file"
    input:
        PATH_BAM+"{sample}.mq20.bam"
    output:
        PATH_BAM+"{sample}.mq20.bam.bai"
    shell:
        """
        samtools index {input}
        """

rule creat_tdf:
    message:
        "creating tdf file"
    input:
        PATH_BAM + "{sample}.mq20.bam"
    output:
        PATH_OUT + "{sample}.tdf"
    conda:
        '../env/igvtool.yaml'
    log:
        PATH_LOG + '{sample}_igv.log'
    params:
        genome = config['igvtool']['genome']
    shell:
        """
            igvtools count -f min,max,mean,median -w 15 {input} {output} {params.genome} &> {log}
        """


def path_relative(path):
    if path[0] is '/':
        return path
    else:
        return srcdir('..') + '/' + path

# Processing ChIP-seq data


#rule sorting_bam:
#    input:
#        PATH_OUT+"{sample}.bam"
#    log:
#        PATH_LOG + 'sorting_{sample}.log'
#    output:
#        temp(PATH_BAM+"{sample}.sorted.bam")
#    shell:
#        """
#            samtools sort {input} -o {output} 2> {log}
#        """

rule mapping_quality_filtering:
    message:
        "mapq filtering"
    input:
        PATH_BAM+"{sample}.bam"
    log:
        PATH_LOG + 'filtering_{sample}.log'
    output:
        PATH_BAM+"{sample}.mq20.bam"
    shell:
        """
            samtools view -b -h -q20 {input} > {output} 2> {log}
        """

rule bamtobed:
    message:
        "converting bam to bed for dfilter"
    input:
        PATH_BAM+"{sample}.mq20.bam"
    output:
        temp(PATH_BAM+"{sample}.mq20.bed")
    shell:
        """
        bamToBed -i {input} > {output}
        """

rule Dfilter_peakcalling:
    message:
        "peak calling - Dfilter"
    input:
        data=PATH_BAM+"{sample}.mq20.bed",
        input=lambda wildcards: PATH_BAM+ PeakCall.loc[PeakCall.Signal == wildcards.sample].Input +".mq20.bed"
    shadow: "shallow"
    params:
        bs = config['dfilter']['bs'],
        ks = config['dfilter']['ks'],
        others = config['dfilter']['others'],
        path = path_relative(config['dfilter']['path'])
    output:
        peak=PATH_PEAKS+"{sample}.dfilter",
        peak_out=PATH_OUT+"{sample}.dfilter"
    log:
        PATH_LOG+"dfilter_{sample}.log"
    shell:
        """
            {params.path}run_dfilter.sh -d={input.data} -c={input.input} -o={output.peak} -bs={params.bs} -ks={params.ks} {params.others} &> {log}
            awk '$NF == 0' {output.peak} > {output.peak_out}
        """

rule MACS_peakcalling:
    message:
        "peak calling - MACS"
    input:
        data=PATH_BAM+"{sample}.mq20.bam",
        input=lambda wildcards: PATH_BAM+PeakCall.loc[PeakCall.Signal == wildcards.sample].Input+".mq20.bam"
    output:
        peak=PATH_PEAKS+"{sample}.macs",
        peak_out=PATH_OUT+"{sample}.macs"
    params:
        bw = config['macs']['bw'],
        m = config['macs']['mfold'],
        p = config['macs']['p_value'],
        g = config['macs']['gsize'],
        other = config['macs']['other']
    log:
        PATH_LOG + "macs_{sample}.log"
    conda:
        '../env/macs.yaml'
    shell:
        """
            macs -t {input.data} -c {input.input} -f AUTO -g {params.g} -n {output.peak} bw {params.bw} -m {params.m} -p {params.p} {params.other} &> {log}
            mv {output.peak}_peaks.bed {output.peak}
            cp {output.peak} {output.peak_out}
        """

def get_ext(argument, sample):
    if argument in ["phantom"]:
        phantom = PATH_QC + sample + '.phantom'
        command = "awk '{print $3 }' < " + phantom + """ | tr ","  "\t" | awk '{if($1!=0) print $1; else print $2}' """
        p = sp.Popen([command], stdout=sp.PIPE, shell=True)
        return p.stdout.read().decode('utf-8').strip('\n')
    else:
        return argument

if config['macs2']['ext'] in ["phantom"]:
    rule MACS2:
        input:
            t=PATH_BAM+'{sample}.mq20.bam',
            i=lambda wildcards: PATH_BAM+PeakCall.loc[PeakCall.Signal == wildcards.sample].Input+".mq20.bam",
            p=PATH_QC+'{sample}.phantom'
        log:
            PATH_LOG + 'macs2_{sample}.log'
        output:
            peak=PATH_OUT+'{sample}.macs2'
        conda:
            '../env/macs2.yaml'
        params:
            name = '{sample}',
            path = PATH_OUT,
            q = config['macs2']['q_thr'],
            g = config['macs2']['gsize'],
            ext = lambda wildcards: get_ext(config['macs2']['ext'], wildcards.sample),
            others = config['macs2']['others']
        shell:
            """
            macs2 callpeak -t {input.t} -c {input.i} -f BAM --gsize {params.g} -n {params.name} --outdir {params.path} -q {params.q} --extsize={params.ext} {params.others} &> {log}
            mv {params.path}/{params.name}_peaks.narrowPeak {output}
            """


else:
    rule MACS2:
        input:
            t=PATH_BAM+'{sample}.mq20.bam',
            i=lambda wildcards: PATH_BAM+PeakCall.loc[PeakCall.Signal == wildcards.sample].Input+".mq20.bam"
        log:
            PATH_LOG + 'macs2_{sample}.log'
        output:
            peak=PATH_OUT+'{sample}.macs2'
        conda:
            '../env/macs2.yaml'
        params:
            name = '{sample}',
            path = PATH_OUT,
            q = config['macs2']['q_thr'],
            g = config['macs2']['gsize'],
            ext = lambda wildcards: get_ext(config['macs2']['ext'], wildcards.sample),
            others = config['macs2']['others']
        shell:
            """
                macs2 callpeak -t {input.t} -c {input.i} -f BAM --gsize {params.g} -n {params.name} --outdir {params.path} -q {params.q} --extsize={params.ext} {params.others} &> {log}
                mv {params.path}/{params.name}_peaks.narrowPeak {output}
            """


rule Intersection:
    message:
        "taking intersection of peakcs"
    input:
        a=lambda wildcards: PATH_OUT+wildcards.sample+'.'+INTERSECT[0],
        b=lambda wildcards: ','.join([PATH_OUT+wildcards.sample+'.'+ext for ext in INTERSECT[1:]])
    output:
        normal=temp(PATH_PEAKS+"{sample}.intersect"),
        filtered=PATH_OUT+"{sample}.peak.intersect",
        chr=PATH_OUT+"{sample}.peak.chr.intersect"
    shell:
        """
           bedtools intersect -a {input.a}  -b {input.b} > {output.normal}
           awk 'a !~ $4; {{a = $4}}' {output.normal} > {output.filtered}
           sed -e 's/^/chr/' {output.filtered} > {output.chr}
        """

