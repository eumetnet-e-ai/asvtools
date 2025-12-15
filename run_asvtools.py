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



import argparse
import asvtools as asv
import subprocess    
import os.path
import numpy as np


########## SEE BOTTOM OF FILE TO DEFINE VARIABLES FOR FUNCTION HERE. !!! ######################## <<<<<<<<<<<<




def main(amplitude=500 ,an_date='today', download:bool = False,run:bool = False,fc_leadtime:int=0):
    """ function description:
        
        asvtools script for running the method.
        
        amplitude   - definies the size (norm) of the perturbations
                        see our underlying paper for recommandations.
        an_date     - defines the date of the analysis 
                        'today' or in form yyyymmdd00 e.g. 2025052600
        download ?  - bool if anaysis state should be downloaded.
        run ?       - bool if a-sv generation should run.
        fc_leadtime - leadtime for forecasts of generated perturbations. "0" means no forecasts 
                        afterwards 
        
        returns: directly nothing.
                 creates the forecasted states in c.SV_RUN_OUTPUT_DIR (iodir/output/)

    """
    ###############################################################################################

    # print properties.
    
    prt_str_warr = ('This is the asvtools package. (c) 2025 Deutscher Wetterdienst (DWD)\n'+
    		"A tiny package to compute 'Arnoldi Singular Vector' (ASV) perturbations. \n"+  	
    		'The software is provided without any warrenty at all.\n'+
    		'See more information at it provided README and LICENCE files.\n'+
                "\n"+
                "\n")

    print( prt_str_warr)
    
    #################################################


    #asv.check_cuda_paths()


    if amplitude<1 or amplitude > 50000:
        raise ValueError("Please choose amplitude between [1-50000]. See more information about "+ 
        		"choice of amplitude in the instructions. Currently chosen amplitude: "+
                            str(amplitude))

    if an_date not in ['TODAY','today'] and download:
        err_an=("You have choosen to download an analysis from opendata.dwd.de and set an "+
                "analysis date. opendata.dwd.de does only provide analysis of the very day.\n"+
                "Do one of the following:\n"+ 
                "a) Choose an_date='today' and download=True\n"+
                "b) download (a bunch of) analysis states and save them at your filesystem. "+
                "Move such an analysis state to input folder and start run_asvtools.py with"+
                "download=False.\n"+
                "c) Get analysis states from somewhere else and start also without download\n"+    
                "d) Implement an addional function to download analysis states from another "+
                "source e.g. ECMWF's ERA5 Reanalysis states.\n"+
                "e) Wait. Probably we will add that named ERA5 feature in the future "+
                "(although this package is not explictly under active development). But we "+
                "recommend to choose another option. You do not know how long it takes.\n\n")
        raise ValueError(err_an)
        

    if isinstance(an_date,str) and an_date in ['TODAY','today']:
        from datetime import datetime

        date_string = f'{datetime.now():%Y%m%d}'
        an_date = str(date_string)+"00"
        print(an_date)

        
    if len(str(an_date)) != 10:
        raise ValueError("'an_date' has to be of type yyyymmdd00")


    
    prt_str = ('start Arnoldi SV algorithm\n\n'+ 
                f"{an_date = }\n" +
                f"{amplitude = }\n" +
                f"{asv.c.AREA = }\n" +
                f"{asv.c.BLOCK_SIZE = }\n"+
                f"{asv.c.LOOPS = }\n"+
                f"{asv.c.T_OPT = }\n"+
                f"{asv.c.SV_VARS = }\n"+
                f"{asv.c.NORM_VARIANT = }\n"+
                f"{asv.c.MODEL = }\n"+
                f"{asv.c.PROCESSUNIT = }\n"+
                "\n")

    print( prt_str)

    if asv.c.NORM_VARIANT == 'energy':
        print("Note: NORM_VARIANT = 'energy' is currently a reduced total energy variant. "+
                "This means that the surface pressure is not taken into account. "+
                "Since the surface pressure is by far the lowest part this is not a big deal. "+
                "But you should know.\n \n")
    
    ###############################################################################################

    if download:
        print('prep analysis data and directories')
        
        #   1. clean everything
        asv.prep_arnoldi_dirs(clean_input_dir=True, keep_Q=False)

        #   2. download det / provide input states.
        subprocess.check_call(['bash', os.path.join(asv.c.SV_WORK_DIR,'get_icon_opendata.sh'), 
                      'opendata' , asv.c.SV_INPUT_DIR ] )
            
        #   3. prepare ref
        list_of_input=asv.get_filepath('input_states')
        #print(list_of_input)
        
        ref_path_npy = asv.prepare_ref(list_of_input[0],'begin')

        
        #asv.prep_arnoldi_dirs(clean_input_dir = False, keep_Q = False)    # clean_input_dir=True)
    else:
        asv.prep_arnoldi_dirs(clean_input_dir=False, keep_Q=False)

        ## clean everything:
        #asv.prep_arnoldi_dirs(clean_input_dir=True, keep_Q=False)
        ##
        ## define specific analysis state
        #an_state_path="/path/to/your/ana_state.nc" 
        #ref_path_npy = asv.prepare_ref(an_state_path,'begin')

    ###############################################################################################
    # run the main asv method.
    if run:    
        print('start arnoldi sv generation')
        asv.arnoldi(amplitude)
    
        print('arnoldi sv generation end')
    
    
    ###############################################################################################			
    # after generation of asv perturbations forecasts thereof might be computed up to a specific
    # forecast leadtime.	
    if run and fc_leadtime >0:
        print('forecast states')    
        
        add_states=[]
        
        append_nr= asv.c.SV_NRS       
        for i in append_nr:
            if i < min(asv.c.SV_CUTOF, asv.c.BLOCK_SIZE*asv.c.LOOPS):
                add_states.append(asv.get_filepath('output',name=asv.c.SV_PERT_FILENAME, 
                            ens_mem=[i], file_ending='.npy'))
        asv.forecast_states(amplitude, fc_leadtime, an_date, state_list=add_states)

        print('end of forecast generation')


    print('asv script end')



###################################################################################################
if __name__ == '__main__':
    """ see function description above 
    
    """
    

    amplitude=500                   # e.g. 2000 (global); 500 (northern hemisphere) 
    an_date= 'today'                # sting in form 'yyyymmdd00' e.g. 2025052500 or 'today'
                                        # NOTE: If you rely on opendata.dwd.de, you can only
                                        # download the data of the same day (use: 'today')
    download=True                  # clean input and download analysis data? bool
    run =False                      # run the a-sv method itself? bool                       
    fc_leadtime=24          # run forecasts of the generated perturbations 
    			    #    choose 0 for no run or a suitable leadtime for forcast runs
    			    #    afterwards. asv.c.SV_NRS determines, which SV are forecasted.

    main(amplitude, an_date, download, run, fc_leadtime )

