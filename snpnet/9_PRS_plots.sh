#!/bin/bash
set -beEuo pipefail

SRCNAME=$(readlink -f $0)
SRCDIR=$(dirname ${SRCNAME})
PROGNAME=$(basename $SRCNAME)
VERSION="0.0.1"
NUM_POS_ARGS="1"

ml load snpnet_yt
# ml load snpnet

############################################################
# functions
############################################################

show_default_helper () {
    cat ${SRCNAME} | grep -n Default | tail -n+3 | awk -v FS=':' '{print $1}' | tr "\n" "\t" 
}

show_default () {
    cat ${SRCNAME} \
        | tail -n+$(show_default_helper | awk -v FS='\t' '{print $1+1}') \
        | head  -n$(show_default_helper | awk -v FS='\t' '{print $2-$1-1}')
}

usage () {
cat <<- EOF
	$PROGNAME (version $VERSION)
	Update the results
	
	Usage: $PROGNAME [options] results_dir
	  results_dir      The output directory for the snpnet
	
	Options:
	  --nCores     (-t)  Number of CPU cores
	  --memory     (-m)  The memory amount
	
	Default configurations:
EOF
    show_default | awk -v spacer="  " '{print spacer $0}'
}

############################################################
# tmp dir
############################################################
tmp_dir_root="$LOCAL_SCRATCH"
if [ ! -d ${tmp_dir_root} ] ; then mkdir -p $tmp_dir_root ; fi
tmp_dir="$(mktemp -p ${tmp_dir_root} -d tmp-$(basename $0)-$(date +%Y%m%d-%H%M%S)-XXXXXXXXXX)"
# echo "tmp_dir = $tmp_dir" >&2
handler_exit () { rm -rf $tmp_dir ; }
trap handler_exit EXIT

############################################################
# parser start
############################################################
## == Default parameters (start) == ##
phe_info_file="pheno.info.tsv"
phe_file="@@@@@@@@@@@@@@@@@@@"
phenotype_name="_AUTO_"
## == Default parameters (end) == ##

declare -a params=()
for OPT in "$@" ; do
    case "$OPT" in 
        '-h' | '--help' )
            usage >&2 ; exit 0 ; 
            ;;
        '-v' | '--version' )
            echo $VERSION ; exit 0 ;
            ;;
        '--phe_file' )
            phe_file=$2 ; shift 2 ;
            ;;
        '--phenotype_name' )
            phenotype_name=$2 ; shift 2 ;
            ;;
        '--'|'-' )
            shift 1 ; params+=( "$@" ) ; break
            ;;
        -*)
            echo "$PROGNAME: illegal option -- '$(echo $1 | sed 's/^-*//')'" 1>&2 ; exit 1
            ;;
        *)
            if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-+ ]]; then
                params+=( "$1" ) ; shift 1
            fi
            ;;
    esac
done

if [ ${#params[@]} -lt ${NUM_POS_ARGS} ]; then
    echo "${PROGNAME}: ${NUM_POS_ARGS} positional arguments are required" >&2
    usage >&2 ; exit 1 ; 
fi

results_dir="${params[0]}"

############################################################

if [ "${phenotype_name}" == "_AUTO_" ] ; then
    phenotype_name=$(basename ${results_dir})
fi

if  [ ! -f "${results_dir}/${phenotype_name}.sscore.png" ] ||
    [ ! -f "${results_dir}/${phenotype_name}.sscore.summary.tsv" ] ; then
    Rscript ${SRCDIR}/9_PRS_plots.R \
    ${phe_info_file} \
    ${phe_file} \
    ${phenotype_name} \
    ${results_dir}/${phenotype_name}.sscore.zst \
    ${results_dir}/${phenotype_name}.sscore.png \
    ${results_dir}/${phenotype_name}.sscore.summary.tsv
fi
