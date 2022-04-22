##########################################################################
# This is the Snakefile of a workflow to filter a repeat library for     #
# protein-coding genes                                                   #
#                                                                        #
#                                                                        #
# 1.0: Written by Verena Kutschera, July 2020                            #
#      (verena.kutschera@scilifelab.se)                                  #
##########################################################################

##########################################################################
########################## SNAKEMAKE PARAMETERS ##########################
##########################################################################

configfile: "config/config.yaml"
import os
PROT_DIR=os.path.dirname(config["PROT"]) + "/"
PROT_FASTA_GZ=os.path.basename(config["PROT"])
PROT_FASTA, PROT_EXT_GZ=os.path.splitext(PROT_FASTA_GZ)
PROT_NAME, PROT_EXT=os.path.splitext(PROT_FASTA)

##########################################################################
############################ SNAKEMAKE RULES #############################
##########################################################################

rule all:
    input:
        repmo_fil = expand(config["OUT_DIR"] + "{rep_lib}/{rep_lib}noProtFinal", rep_lib=config["REP_LIBS"])

rule split_uniprot:
    """Split the UniProt/Swissprot protein database into chunks for transposonPSI"""
    input: 
        prot = config["PROT"] # curated proteins from swissprot/uniprot
    output:
        chunks = temp(expand(PROT_DIR + "split_result/" + PROT_NAME + "_chunk{nr}.fa", nr=range(1, 101)))
    params:
        dir = PROT_DIR,
        prot = PROT_NAME,
        prot_path = PROT_DIR + PROT_NAME
    conda: "envs/gaas.yaml"
    shell:
        """
        cd {params.dir}
        gunzip {input.prot} &&
        gaas_fasta_splitter.pl -f {params.prot} --nb_chunks 100 -o tmp &&
        mv tmp/*.fa split_result/ && rm -r tmp/ &&
        gzip {params.prot_path}
        """

rule transposonPSI:
    """Identify transposons in the UniProt/Swissprot protein dataset"""
    input:
        chunk = PROT_DIR + "split_result/" + PROT_NAME + "_chunk{nr}.fa"
    output:
        allHits = temp(PROT_DIR + "split_result/" + PROT_NAME + "_chunk{nr}.fa.TPSI.allHits"),
        topHits = temp(PROT_DIR + "split_result/" + PROT_NAME + "_chunk{nr}.fa.TPSI.topHits")
    params:
        dir = PROT_DIR + "split_result/"
    conda: "envs/tePSI.yaml"
    shell:
        """
        cd {params.dir}
        transposonPSI.pl {input.chunk} prot
        """

rule list_tePSI_hits:
    input:
        topHits = expand(PROT_DIR + "split_result/" + PROT_NAME + "_chunk{nr}.fa.TPSI.topHits", nr=range(1, 101))
    output:
        allTopHits = PROT_DIR + PROT_NAME + ".TPSI.topHits",
        prot_list = PROT_DIR + PROT_NAME + ".TPSI.topHits.accessions.txt"
    shell:
        """
        cat {input.topHits} > {output.allTopHits} &&
        awk '{{if($0 ~ /^[^\/\/.*]/) print $5}}' {output.allTopHits} | sort -u > {output.prot_list}
        """

rule filter_uniprot_fasta:
    """Remove transposons from the UniProt/Swissprot protein dataset"""
    input:
        prot = config["PROT"],
        prot_list = PROT_DIR + PROT_NAME + ".TPSI.topHits.accessions.txt"
    output:
        prot_filtered = PROT_DIR + PROT_NAME + ".noTEs.fa"
    params:
        dir = PROT_DIR,
        prot_path = PROT_DIR + PROT_FASTA
    conda: "envs/gaas.yaml"
    shell:
        """
        cd {params.dir}
        gunzip {input.prot} &&
        gaas_fasta_removeSeqFromIDlist.pl -f {params.prot_path} -l {input.prot_list} -o {output.prot_filtered} &&
        gzip {params.prot_path}
        """

rule filtered_blast_db:
    """Generate BLAST database from filtered UniProt/Swissprot protein dataset"""
    input: 
        prot_filtered = PROT_DIR + PROT_NAME + ".noTEs.fa"
    output:
        phr = PROT_DIR + PROT_NAME + ".noTEs.fa.phr",
        pin = PROT_DIR + PROT_NAME + ".noTEs.fa.pin",
        psq = PROT_DIR + PROT_NAME + ".noTEs.fa.psq"
    params:
        dir = PROT_DIR
    conda: "envs/blast.yaml"
    shell:
        """
        cd {params.dir}
        makeblastdb -in {input.prot_filtered} -dbtype prot
        """

rule symbolic_links:
    """Create symbolic links to repeat libraries in output directory"""
    input:
        repmo_raw = config["REP_DIR"] + "{rep_lib}"
    output:
        sym_link = config["OUT_DIR"] + "{rep_lib}/{rep_lib}"
    shell:
        """
        ln -s {input.repmo_raw} {output.sym_link}
        """

rule blast_repeat_library:
    """Blastx repeat library to filtered Uniprot/Swissprot database"""
    input:
        repmo_raw = config["OUT_DIR"] + "{rep_lib}/{rep_lib}",
        blast_db_idx = rules.filtered_blast_db.output,
        blast_db = PROT_DIR + PROT_NAME + ".noTEs.fa"
    output:
        blast = config["OUT_DIR"] + "{rep_lib}/{rep_lib}.blastx.out"
    params:
        dir = config["OUT_DIR"] + "{rep_lib}/"
    threads: 8
    conda: "envs/blast.yaml"
    shell:
        """
        cd {params.dir}
        blastx -num_threads {threads} -db {input.blast_db} -query {input.repmo_raw} -out {output.blast}
        """

rule protexcluder:
    """Remove blast hits from repeat library"""
    input:
        repmo_raw = config["OUT_DIR"] + "{rep_lib}/{rep_lib}",
        blast = config["OUT_DIR"] + "{rep_lib}/{rep_lib}.blastx.out"
    output:
        repmo_fil = config["OUT_DIR"] + "{rep_lib}/{rep_lib}noProtFinal"
    params:
        dir = config["OUT_DIR"] + "{rep_lib}/"
    conda: "envs/protexcluder.yaml"
    shell:
        """
        cd {params.dir}
        ProtExcluder.pl {input.blast} {input.repmo_raw}
        """
