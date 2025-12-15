#!/bin/bash   
###################################################################################################
#    
#    asvtools - Copyright 2025 Deutscher Wetterdienst (DWD)
#    Licenced under BSD-3-Clause License
#
#    Redistribution and use in source and binary forms, with or without modification, are permitted 
#    provided that the following conditions are met:
#
#    1. Redistributions of source code must retain the above copyright notice, this list of 
#	conditions and the following disclaimer.
#
#    2. Redistributions in binary form must reproduce the above copyright notice, this list of 
#    	conditions and the following disclaimer in the documentation and/or other materials 
#    	provided with the distribution.
#
#    3. Neither the name of the copyright holder nor the names of its contributors may be used to 
#    	endorse or promote products derived from this software without specific prior written 
#	permission.
#
#    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR 
#    IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
#    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
#    CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR  
#    CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR  
#    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  
#    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR  
#    OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
#    POSSIBILITY OF SUCH DAMAGE.
#
###################################################################################################



display_help() {
    echo "  USAGE:"
    echo "  ./get_icon_opendata.sh  variant  input_dir"
    echo "                      'opendata'  INPUT_DIR"
    echo ""
    echo "                       -h" 
    echo "" 
    echo ""                            
    echo "   1.  ./get_icon_opendata.sh    'opendata'  INPUT_DIR"
    echo ""       
    echo "           download the anlysis data of today from opendata.dwd.de"
    echo "	     and transforms it from icon-grid to a lat-lon-grid"
    echo "	     and stores it into given 'INPUT_DIR'"
    echo "		(note opendata.dwd.de provides only the most recent data)"
    echo ""
    echo "   2.  ./get_icon_opendata.sh    PATH_TO_DATA_ON_ICON_GRID_GRIBFILE   INPUT_DIR"
    echo ""       
    echo "           provide a path to a local suitable analysis on icon_grid in grib in order to"
    echo "	     transform it to lat-lon-grid as netcdf"
    echo "	     and stores it into given 'INPUT_DIR'"
    echo ""
    echo "   ./get_icon_opendata.sh    -h"
    echo ""
    echo "	     show this helptext"

    exit 0
}
###################################################################################################
#
#   get_icon_opendata gets icon analysis data and transforms it for the pangu-weather fc model. 
#               the file will be a netcdf file.
#               a grib file will be transformed to netcdf.
#
#
#   it creates a netcdf4 file $AN_FILE_LL which is on a lat lon grid (res 025) on pressure levels
#       contains:   a) the athmospheric upper air data 
#                   b) the surface data.
#       upper air:  FI(Z),QV or RELHUM,T,U,V - lev: 
#                                       1000 925 850 700 600 500 400 300 250 200 150 100 50 hPa
#       surface:    PMSL,U_10M,V_10M,T_2M
#
###################################################################################################
#   see asvtools README	
#
#   README (short, for this script)
#   install first:
#
#       1. eccodes
#           see: https://confluence.ecmwf.int/display/ECC/ecCodes+installation
#            needs to be compliled by you.
#       ############
#       2. netcdf
#           see: https://docs.unidata.ucar.edu/nug/current/getting_and_building_netcdf.html
#           There are some pre compliled versions. Probably you can use such a version but
#           maybe it is saver to complile by your own. Not sure.
#       ############
#       3. cdo (climate data operations)
#           see: https://code.mpimet.mpg.de/projects/cdo
#       Read readme of package there.
#       IMPORTANT: See the cdo instructions. You need to ensure that cdo takes eccodes and netcdf 
#		into account. The following configure-command, which denotes the eccodes an netcdf 
#		paths should be suitable.
#           ./configure --with-eccodes="PATH_TO_ECCODES_DIR"  --with-netcdf="PATH_TO_NETCDF_DIR"
#           Hence, netcdf and eccodes must be installed before.
#
###################################################################################################

transform_from_grib() {

        echo 'transform from grib'


        GRIDNR=$(grib_get -w count=1 -p gridDefinitionTemplateNumber "$1")
    
        if [ $GRIDNR == "101" ]; then

            CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
                    ## read numberOfGridUsed  from first message
            GNUM=$(grib_get -w count=1 -p numberOfGridUsed "$1")
            GNUM="00${GNUM}"

            if [ "$GNUM" == "0024" ]; then 
                RB="R02B06"
            elif [ "$GNUM" == "0026" ]; then 
                RB="R03B07"
            elif [ "$GNUM" == "0030" ]; then 
                RB="R02B05"
            elif [ "$GNUM" == "0033" ]; then 
                RB="R03B05"
            elif [ "$GNUM" == "0036" ]; then 
                RB="R03B06"
            else
                echo "Grid ${GNUM} is not available or not implemented."
                exit 1
            fi


            echo "Grid ${GNUM} ${RB}"

            WEIGHTS_FILE="${CURR_DIR}/weights_icon_${GNUM}_${RB}_world_025.nc"
            LATLON_GRID_DE="${CURR_DIR}/target_grid_world_025.txt"

            ICON_GRID_FILE_NAME="icon_grid_${GNUM}_${RB}_G.nc"
            

            if [ ! -f $WEIGHTS_FILE ]; then
                echo "compute weights file"
                if [ ! -f "${CURR_DIR}/${ICON_GRID_FILE_NAME}" ]; then
                    echo "download icon grid file"
                    GRID_URL="http://icon-downloads.mpimet.mpg.de/grids/public/edzw/" 
                    wget ${GRID_URL}${ICON_GRID_FILE_NAME} -P ${CURR_DIR}
                fi
                cdo gennn,${LATLON_GRID_DE} ${CURR_DIR}/${ICON_GRID_FILE_NAME} ${WEIGHTS_FILE}
            fi

            prec="-b F32"
            #form="-f nc4c -z zip"
            form="-f nc4c"
            #form="-f grb2"
             
                               
            cdo ${prec} ${form} remap,${LATLON_GRID_DE},${WEIGHTS_FILE} "$1" "$2"
        
        elif [ $GRIDNR == "0" ]; then

            cdo -f nc copy "${1}" "${2}"
        else
            echo "file not usable."
            echo "unknown 'gridDefinitionTemplateNumber'" 
            echo "Has to be 0 (regular_ll) or 101 (ICON-grid denoted as 'unstructured grid')"
            exit 5     
        fi

}
    





###################################################################################################


CURR_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
input_data_dir="${2}"



variant=$1

if [ "$1" == "-h" ] ; then
    display_help
    exit 0
fi




###################################################################################################

if [ "$variant" == "opendata" ]; then

    initdate=$(date -d "0 days ago" +%Y%m%d)
    hour=$(date -d "0 days ago" +%H)

    # bug: for some reason problems with inittime = 12 
    #if (( 10#$hour < 13 )); then inittime="00";fi
    #if (( 10#$hour > 13 )); then inittime="12";fi
    #if (( 10#$hour < 1 )); then inittime="00";fi
    inittime="00"

    AN_DATE=${initdate}${inittime} 


    AN_NAME="i2p_od_${AN_DATE}"


    #state_file_p="${input_data_dir}/${AN_NAME}"
    #state_file_sfc="${input_data_dir}/${AN_NAME}_sfc"

    AN_FILE_LL="${input_data_dir}/${AN_NAME}_ll25"
    #state_file_ll_sfc="${input_data_dir}/${AN_NAME}_ll25_sfc"

    if [ ! -f $AN_FILE_LL ]; then

        urlpath="https://opendata.dwd.de/weather/nwp/icon/grib"

        # pressure levels in given in hPA at opendata.dwd.de (instead of Pa for Sky-DB requests.) 
        plevels="1000 925 850 700 600 500 400 300 250 200 150 100 50"
        pvars="fi relhum t u v"
        prefix="icon_global_icosahedral_"
        postfix=".grib2.bz2"

        sfcvars="pmsl u_10m v_10m t_2m"


        prec="-b F32"
        #form="-f nc4c -z zip"
        form="-f nc4c"
        #form="-f grb2"

        ###########################################################################################
        # prepare upper air data
        
        # Loop over pvars
        level="pressure-level_"
        for var in ${pvars}; do
            for lev in ${plevels}; do
                # specify file
        	    filename=${prefix}${level}${initdate}${inittime}_000_${lev}_${var^^}
        	    echo ${urlpath}/${inittime}/${var}/${filename}${postfix}

                # download
                wget ${urlpath}/${inittime}/${var}/${filename}${postfix} -P ${input_data_dir}   #--directory-prefix=
                # unzip
        	    bunzip2 ${input_data_dir}/$filename${postfix}
                # remap to required latlon grid
                #cdo ${prec} ${form} remap,target_grid_world_025.txt,weights_icogl2world_025.nc \
#${input_data_dir}/$filename.grib2 ${input_data_dir}/$filename.nc
                transform_from_grib ${input_data_dir}/$filename.grib2 ${input_data_dir}/$filename.nc

                # delete org file	
                rm -f ${input_data_dir}/$filename.grib2
            done

        
            # merge files of levels into file with one level
            cdo ${prec} ${form} merge ${input_data_dir}/${prefix}${level}${initdate}${inittime}\
_000_{1000,925,850,700,600,500,400,300,250,200,150,100,50}_${var^^}.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}_000_all_levs_${var^^}.nc
        done

        # merge upper air variable files together
        cdo ${prec} ${form} merge ${input_data_dir}/${prefix}${level}${initdate}${inittime}\
_000_all_levs_*.nc ${input_data_dir}/${prefix}${level}${initdate}${inittime}_000_all.nc

        # delete files
        rm -f ${input_data_dir}/${prefix}${level}${initdate}${inittime}*FI.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*RELHUM.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*T.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*U.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*V.nc

        
        # nc file with levels and upper air vars created.
        ###########################################################################################
        # prepare surface data

        # Loop over sfcvars
        level="single-level_"
        for var in ${sfcvars}; do
            # set filename
            filename=${prefix}${level}${initdate}${inittime}_000_${var^^}
            # download data und unzip    
            wget ${urlpath}/${inittime}/${var}/${filename}${postfix} -P ${input_data_dir}
            bunzip2 ${input_data_dir}/$filename${postfix}
            # remap to required latlon grid
            #cdo ${prec} ${form} remap,target_grid_world_025.txt,weights_icogl2world_025.nc \
            transform_from_grib ${input_data_dir}/$filename.grib2 ${input_data_dir}/$filename.nc
            rm -f ${input_data_dir}/$filename.grib2
        done

        # merge surface variable files togehter
        cdo ${prec} ${form} merge ${input_data_dir}/${prefix}${level}${initdate}${inittime}*.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}_000_all.nc

        rm -f ${input_data_dir}/${prefix}${level}${initdate}${inittime}*PMSL.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*U_10M.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*V_10M.nc \
${input_data_dir}/${prefix}${level}${initdate}${inittime}*T_2M.nc


        #form="-f grb2"
        p_level="pressure-level_"
        # merge sfc and upper air file together.
        cdo -O ${prec} ${form} merge ${input_data_dir}/${prefix}${p_level}${initdate}${inittime}\
_000_all.nc ${input_data_dir}/${prefix}${level}${initdate}${inittime}_000_all.nc ${AN_FILE_LL}


        rm -f ${input_data_dir}/${prefix}${level}${initdate}${inittime}_000_all.nc
        rm -f ${input_data_dir}/${prefix}${p_level}${initdate}${inittime}_000_all.nc
    fi
    echo "surface and pressure files available"
###################################################################################################

elif [ -f "${variant}" ]; then

    echo "Use file ${variant} as input."
    ###############################################################################################
    # checks
    echo "Note: Few checks done in this variant. If data is not suitable, it may cause errors."


    ###############################################################################################
    # det mode

    AN_NAME=$(basename -- "$variant")
    AN_NAME="${AN_NAME%.*}"
    
    AN_FILE_LL="${input_data_dir}/${AN_NAME}_ll25"
    
    
    echo 'from icon_grid in grib to lat-lon-grid in netcdf'
    if [ ! -f "${AN_FILE_LL}" ]; then
            transform_from_grib ${variant} ${AN_FILE_LL}
    else
           echo "File does already exist. No transformation or copy is done."   
    fi            

# start from file
else      

    echo "${variant} does not exist."
    echo ""                
    echo "VARIANT has to refer to a file if none of the other valid options were choosen."
    exit 2
    

   
fi
###################################################################################################



