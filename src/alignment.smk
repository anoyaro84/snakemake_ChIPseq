


def data_from_forge(sample, FullPath, path, ext="bam"):
    if ext=="bam":
        if len(FullPath[str(sample)]) == 1:
            print(FullPath[str(sample)][0])
            os.system("wget -c -N " + FullPath[str(sample)][0] + " -O " + path + str(sample) + ".bam")
        else:
            command = "samtools merge " + path + str(sample) + ".bam"
            rmcommand = "rm -rf "
            for i in range(len(FullPath[str(sample)])):
                print(FullPath[str(sample)][i])
                os.system("wget -c -N " + FullPath[str(sample)][i] + " -O " + str(sample) +  str(i) + '.bam')
                command = command + " "  + str(sample) + str(i) + ".bam"
                rmcommand = rmcommand + str(sample) + str(i) + ".bam"
            print(command)
            os.system(command)
            os.system(rmcommand)

    if ext=="fastq.gz":
        print(FullPath[str(sample)][0])
        os.system("wget -N " + FullPath[str(sample)][0] + " -O" + path + str(sample) + ".fastq.gz")



def fastq_dump(sample, PATH_FASTQ, PATH_LOG):
    print(sample)
    SRRs = query_SRR(str(sample), path_ncbitoolkit=PATH_EDIRECT) # get SRR accession from GSM ID

    for i in range(len(SRRs)):
        SRRs[i] = SRRs[i].split("\n")[0]

    print(SRRs)
    if not os.path.exists(PATH_LOG):
        os.makedirs(PATH_LOG)

    for SRR in SRRs:
        stdout_fn = Path(PATH_LOG + SRR + ".fastq_dump.log")
        if not os.path.isfile(PATH_FASTQ+SRR+'.fastq.gz'):
            print('fastq-dump : ' + SRR)
            with stdout_fn.open('w') as stdout_f:
                p = sp.run([PATH_SRATOOL+'fastq-dump', '--split-3', '--skip-technical',
                            '-I', '--gzip', '-O', PATH_FASTQ, SRR], stderr=stdout_f)

    if len(SRRs)>1:
        outfile = Path(PATH_FASTQ+str(sample)+'.fastq.gz')
        command = ['cat']
        for SRR in SRRs:
            command.append(PATH_FASTQ+SRR+'.fastq.gz')
        with outfile.open('w') as out:
            print(command)
            p = sp.run(command, stdout=out)
    else:
        p = sp.run(['mv', PATH_FASTQ + SRRs[0] + '.fastq.gz', PATH_FASTQ + str(sample) + '.fastq.gz'])

#rule fastq_dump:
#    output:
#        temp(PATH_FASTQ + "{sample}.fastq.gz")
#    run:
#        fastq_dump(wildcards.sample)

rule prepare_raw_files:
    output:
        expand(PATH_FASTQ + '{sample}.fastq.gz', sample=GEOID+WZID_FASTQ+Local_FASTQ),
        expand(PATH_BAM + '{sample}.bam', sample=WZID_BAM+Local_BAM),
    run:
        Files, FullPath_BAM = get_paths(WZID_BAM, PATH_DATA, ext='bam')
        Files, FullPath_FASTQ = get_paths(WZID_FASTQ, PATH_DATA, ext='fastq.gz')

        for local in PATH_LOCAL_BAM:
            copyfile(PATH_LOCAL_BAM[local], PATH_BAM + local + '.bam')
        for local in PATH_LOCAL_FASTQ:
            copyfile(PATH_LOCAL_FASTQ[local], PATH_FASTQ + local + '.fastq.gz')
        for wz in WZID_BAM:
            data_from_forge(wz, FullPath_BAM , ext="bam", path=PATH_BAM)
        for wz in WZID_FASTQ:
            data_from_forge(wz, FullPath_FASTQ, ext="fastq.gz", path=PATH_FASTQ)
        for geo in GEOID:
            fastq_dump(geo, PATH_FASTQ, PATH_LOG)

rule bwa_aln:
    input:
        PATH_FASTQ + "{sample}.fastq.gz"
    output:
        PATH_BAM + "{sample,[A-Za-z0-9_-]+}.bam"
    log:
        PATH_LOG + "{sample}.bwa.log"
    params:
        index = REFLIB,
        sort = 'samtools'
    threads:
        config['Ncores']
    wrapper:
        "0.17.4/bio/bwa/mem"



#rule bwa_aln:
#    input:
#        PATH_FASTQ + "{sample}.fastq.gz"
#    output:
#        sai=temp(PATH_FASTQ + "{sample}.sai"),
#        sam=temp(PATH_FASTQ + "{sample}.sam"),
#        bam=PATH_OUT + "{sample}.bam"
#    log:
#        aln=PATH_LOG + "{sample}.aln.log",
#        samse=PATH_LOG + "{sample}.samse.log",
#        samtool=PATH_LOG + "{sample}.samtobam.log"
#    params:
#        RefSeq
#    shell:
#        """
#        bwa aln {params} {input} > {output.sai} 2> {log.aln}\n
#        bwa samse {params} {output.sai} {input} > {output.sam} 2> {log.samse}\n
#        samtools view -Sb {output.sam} > {output.bam} 2> {log.samtool}
#        """


