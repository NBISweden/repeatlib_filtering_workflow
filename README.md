# Repeat library filtering

This Snakemake workflow was developed to filter a repeat library for TEs resembling proteins.
It was written for execution on a HPC cluster and the slurm workload manager for job submission.

The workflow consists of the following files and directories:

- README: this file, containing the documentation.
- `Snakefile`: contains some python code and rules with code to be executed. Each rule will be submitted as a job to the cluster.
- `config/config.yaml`: contains parameters and paths to input and output files. Needs to be manually edited before running the workflow.
- `config/cluster.yaml`: contains parameters for slurm jobs.
- `envs/` directory with conda environments required by most of the rules.

## Analyses

- Splits the UniProt/SwissProt fasta file (reviewed proteins) into chunks using a script from GAAS (NBIS annotation platform scripts)
- Runs transposonPSI on each UniProt/SwissProt fasta chunk to identify protein sequences with sequence similarity to transposons
- Removes proteins with similarity to transposons from the UniProt/SwissProt fasta file using a script from GAAS (NBIS annotation platform scripts)
- Generates a BLAST database from the filtered UniProt/SwissProt fasta file (BLAST version 2.7.1+ due to compatibility issues with ProtExcluder)
- BLASTs the repeat library to the filtered Uniprot/Swissprot database using BLASTx (BLAST version 2.7.1+)
- Removes BLAST hits from the repeat library using ProtExcluder


## Requirements

- Miniconda or Anaconda is required as most of the rules use conda environments
- A Fasta file with proteins from UniProt/Swissprot (reviewed proteins) needs to be downloaded and provided via the configuration file (`config.yaml`)


## How to run this workflow on a new repeat library

- Clone this repository to your HPC cluster
- This workflow has been previously run with the slurm workload manager with cluster configuration via `--cluster-config`. 
  Although the cluster configuration option is available, it is deprecated and might disappear in future Snakemake versions, 
  and the official Snakemake slurm profile (https://github.com/Snakemake-Profiles/slurm) is now the preferred way. In both cases, 
  computational resources for the different jobs that are submitted to the cluster via Snakemake are specified in the cluster 
  configuration file `config/cluster.yaml`. Prior to continuing, edit the header section of the `config/cluster.yaml` file so 
  that it includes an active compute project ID.
- Edit the config file `config/config.yaml`, following the instructions there
- The first time you run the workflow, create a conda environment from the file "envs/snakemake5191_py36.yaml" for Snakemake 
  (see https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html#creating-an-environment-from-an-environment-yml-file 
  for more info on how to create conda environments). Note that the workflow was developed and tested with Snakemake version 5.19.1.

### Running the workflow with a Snakemake slurm profile (preferred way)

> The first time you run the workflow, you need to set up the Snakemake slurm profile for the workflow. 
> First, you need to install cookiecutter with conda/mamba (`conda install -c conda-forge cookiecutter`). 
> Next, download the Snakemake slurm profile and set it up:
> Move to the workflow directory (`path/to/your/snakemake_run`)
> Execute `$ cookiecutter https://github.com/Snakemake-Profiles/slurm.git` and fill in the following when asked on the command line:
> profile_name [slurm]: slurm # or any other name, e.g. the name of your cluster
> sbatch_defaults []: (press ENTER)
> cluster_config []: config/cluster.yaml
> Select advanced_argument_conversion:
> 1 - no
> 2 - yes
> Choose from 1, 2 [1]: 1
> cluster_name []: # either enter the name of your cluster or press ENTER

- Start a tmux or screen session to run the workflow in the background (check https://tmuxcheatsheet.com/ for how to use tmux)

- Activate the conda environment 

    `$ conda activate sm5191py36`

- Run the workflow in dry mode

    `$ snakemake -npr -j 100 --use-conda --profile slurm &> YYMMDD_dry_run.out`

- Create a dag file and inspect it manually

    `$ snakemake --dag | dot -Tsvg > dag_dry.svg`

- Start the main run

    `$ snakemake -j 100 --use-conda --profile slurm  &> YYMMDD_main_run.out`

> Note: Conda will create the environments used by the different workflow rules at the start of the first workflow run.
> In case this process takes a long time, try to start the main run with the additional parameter `--conda-frontend mamba`.

- Create a dag file after the main run is finished and inspect it manually

    `$ snakemake --dag | dot -Tsvg > dag_main.svg`


### Running the workflow with the cluster configuration file `config/cluster.yaml`

- Start a tmux or screen session to run the workflow in the background (check https://tmuxcheatsheet.com/ for how to use tmux)

- Activate the conda environment 

    `$ conda activate sm5191py36`

- Run the workflow in dry mode

    `$ snakemake -npr -j 100 --use-conda --cluster-config cluster.yaml --cluster "sbatch -A {cluster.account} -p {cluster.partition} -n {cluster.n}  -t {cluster.time}" &> YYMMDD_dry_run.out`

- Create a dag file and inspect it manually

    `$ snakemake --dag | dot -Tsvg > dag_dry.svg`

- Start the main run

    `$ snakemake -j 100 --use-conda --cluster-config cluster.yaml --cluster "sbatch -A {cluster.account} -p {cluster.partition} -n {cluster.n}  -t {cluster.time}" &> YYMMDD_main_run.out`

> Note: Conda will create the environments used by the different workflow rules at the start of the first workflow run.
> In case this process takes a long time, try to start the main run with the additional parameter `--conda-frontend mamba`.

- Create a dag file after the main run is finished and inspect it manually

    `$ snakemake --dag | dot -Tsvg > dag_main.svg`

