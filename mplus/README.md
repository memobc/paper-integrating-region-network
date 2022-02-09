## MPLUS Modeling

This directory contains data and syntax files for running all SEMs in MPLUS. See [MPLUS documentation](http://www.statmodel.com/) for more information on the syntax. The files are organized as follows:  

`data-{DATA}_modelType-{MODELTYPE}_measureModel-{MEASUREMODEL}_model-{MODELNAME}.inp`  
`data-{DATA}_modelType-{MODELTYPE}_measureModel-{MEASUREMODEL}_model-{MODELNAME}.out`  

- _DATA_: can take on the values `behav`, `neural`, or `all` depending on the subset of data that is included in the model  
- _MODELTYPE_: can take on the values `null`, `Measurement`, `Structural`  
- _MEASUREMODEL_: can take on the values `null`, `SingleFactor`, `TwoFactor`, or `MetricInvariance`  
- _MODELNAME_: an additional, short descriptor to differentiate models. See below for more information.  

Model Name Long Descriptions:  

- `Model0`: a "baseline" structural model, containing a structural path from the neural latent variable(s) to the behavioral latent variable.  
- `Model0vPMN`: in the TwoFactor model only, this model refers to one where the only structural path is from the __vPMN__ latent variable --> __MemoryQuality__.  
- `Model0dPMN`: in the TwoFactor model only, this model refers to one where the only structural path is from the __dPMN__ latent variable --> __MemoryQuality__.  
- `Model1`: contains all of the paths from `Model0`, with the addition of a unique path from the __HIPP__ --> __MemoryQuality__  
- `Model2`: contains all of the paths from `Model0`, with the addition of a unique path from the __PREC__ --> __MemoryQuality__  
- `Model3`: contains all of the paths from `Model0`, with the addition of a unique path from the __PCC__ --> __MemoryQuality__  
- `Model4`: contains all of the paths from `Model0`, with the addition of a unique path from the __MPFC__ --> __MemoryQuality__  
- `Model5`: contains all of the paths from `Model0`, with the addition of a unique path from the __PHC__ --> __MemoryQuality__  
- `Model6`: contains all of the paths from `Model0`, with the addition of a unique path from the __RSC__ --> __MemoryQuality__  
- `Model7`: contains all of the paths from `Model0`, with the addition of a unique path from the __aAG__ --> __MemoryQuality__  
- `Model8`: contains all of the paths from `Model0`, with the addition of a unique path from the __pAG__ --> __MemoryQuality__  

The neural measurement models were fit using the MLR estimator in MPlus. We note here that we received a warning from MPlus concerning a non-positive definite first-order derivative product matrix. This is most likely due to having a larger number of parameters than samples at the between-subjects level. This warning should not influence parameter and model fit estimates for our purposes. See https://statmodel.com/download/ConditionNumber.pdf for more information.
