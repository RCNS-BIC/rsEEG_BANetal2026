# rsEEG_repo
Repository containing the resting-state EEG pre-processing pipeline utilised in the manuscript:
Bán, K., Weiss, B., Auer, T., Gajewski, P.D., Wascher, E., Vidnyánszky, Z. (2026). Cognitive exertion reshapes resting-state EEG markers of ageing. bioRxiv 2026.08.14.744886; doi: https://doi.org/10.64898/2026.08.14.744886

The pipeline is conducted in Automatic Analysis (aa; version 5.8.1), runs on MATLAB (version 2024b, The Mathworks Inc., 2024) and utilises EEGLab (version 2024.2), and FieldTrip (git revision 2755b10) functionalities. It allows for parallel processing as well as the co-registration of structural MRI (T1-weighted) images to support ICA classification. The current IC classification thresholds were selected based on manual inspection of thousands of components from the validation dataset. For details on each step, see the manuscript above.

Files
- aap_prov.png displays the pre-processing and spectral analysis steps
- For pre-processing and running the spectral parametrisation on the Dortmund Vital study data, use meeg_dvs_neuropsych.m. Please note that the utilised processing modules are in specified in meeg_dvs_neuropsych.xml.
- For pre-processing and running the spectral parametrisation on the validation data, use meeg_validation.m. Please note that the order of steps in specified in meeg_validation.xml.

Please also note that the validation pipeline was also used to process task data, which is beyond the scope of the article above. 

If you have any questions, please feel free to get in touch with the corresponding authors. 




