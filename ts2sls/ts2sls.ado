*! version 0.2 January 16, 2020 @ 16:57:16
/*
ts2sls.ado
J. SHRADER
jgshrade@ucsd.edu
First Version: 2014/10/30

Stata program to calculate two-sample two-stage least squares (TS2SLS) estimates.
Math is based on Inoue and Solon (2005), although variable names more closely
follow the shorter version published as Inoue and Solon (2010).

Syntax
ts2sls y (x = z) [if] [in], group(group_var) [noconstant]

Where y is the outcome variable, x be the endogenous regressor, and z an exogenous
instrument. I follow the notation of Inoue and Solon and call the data for
estimating the reduced form (y as a function of z) "group 1" and the data for
estimating the first stage (x as a function of z) "group 2". 

Some of the code is taken more or less directly from Solomon Hsiang's
ols_spatial_HAC.ado file.

If you find errors, please let me know.

References:

Angrist, Joshua D., and Alan B. Krueger. "The effect of age at school entry on
educational attainment: an application of instrumental variables with moments
from two samples." Journal of the American Statistical Association 87, no. 418
(1992): 328-336.

Inoue, Atsushi, and Gary Solon. "Two-sample instrumental variables
estimators." The Review of Economics and Statistics 92, no. 3 (2010): 557-561.

Inoue, Atsushi, and Gary Solon. "Two-Sample Instrumental Variables
Estimators." NBER Working Paper (2005).
*/
program ts2sls, eclass byable(recall)
version 12
   // _iv_parse.ado is a core Stata ado file to parse IV-style commands
   _iv_parse `0'
   // Estimation is always GMM, so just get variables
   local lhs `s(lhs)'
   local endog `s(endog)'
   local exog `s(exog)'
   local inst `s(inst)'
   // Pass the rest to `0' to go into standard syntax
   local 0 `s(zero)'
   syntax [if] [in] , GROUP(varname) [NOConstant FIRST] 

   // Pull correct sample
   marksample touse
	markout `touse' `inst'

   // Populate lists based on fully expanded list
	local totexp `endog' `exog' `inst'
	fvexpand `totexp' if `touse'
	local totexp `r(varlist)'
	fvexpand `endog' if `touse'
	local endog `r(varlist)'
	fvexpand `exog' if `touse'
	local exog `r(varlist)'
	fvexpand `inst' if `touse'
	local inst `r(varlist)'
	foreach vargroup in endog exog inst {
		local there: list `vargroup' & totexp
		local leftover: list `vargroup' - there
		foreach var of local leftover {
			_ms_put_omit `var'
			local there `there' `s(ospec)'
		}
		local `vargroup' `there'
	}

	// Remove colinear variables using the method from ivregress
   tempvar _one
   gen byte `_one' = 1
   //CheckCollin `lhs' if `touse' & `group'==2 [iw=`_one'], ///
   //  endog(`endog') exog(`exog') inst(`inst')
	local endog `s(endog)'
	local exog `s(exog)'
	local inst `s(inst)'
	local fvops `s(fvops)'
	local tsops `s(tsops)'
   if "`noconstant'" == "" {
      local exogc `exog' `_one'
      local endogfs `endog' `exog' `_one'
      local instfs `inst' `exog' `_one'
   }
   else {
      local exogc `exog'
      local endogfs `endog' `exog'
      local instfs `inst' `exog'
   }
   

   // Create group variables
   // We use the notation of Inoue and Solon and call the first stage data "group
   // 2" and the reduced form data "group 1"
   // Need method to make sure that group only takes 2 values
   quietly: tab `group'
   tempvar _group1
   gen byte `_group1' = (`group' == 1)
   tempvar _group2
   gen byte `_group2' = (`group' == 2)

   // Fill in the rest of the required elements for doFirst
   // These should probably be cleaned up in the future
   local endogname `endog'
   local exogname `exog'
   local instname `inst'
   local timevar ""
   local tvardelta ""
   local hasconstant ""
   local vcetype = "unadj"
   local vceclustervar = ""
   local vcehac = ""
   local vcehaclag = ""

   // We are not weighting, but we have to do some handling of this to appease
   // the Stata-written functions
   tempvar normwt 
   qui gen double `normwt' = 1 if `touse'
   qui count if `_group1'
   local normN1 = r(N)
   qui count if `_group2'
   local normN2 = r(N)

   // There are lots of other methods from ivregress that we could adopt:
   // . Making sure number of endogenous vars <= instruments (`indo_ct' > `inst_ct')
   // . Checking the number of clusters in our robust SE code


   // First stage
   // This is another function stolen from ivregress.ado
   // Use only Group 2
   tempvar touse2
   gen `touse2' = (`touse' & `group' == 2)
   tempvar touse1
   gen `touse1' = (`touse' & `group' == 1)
   if "`first'"!= "" {
      doFirst `"`endog'"' `"`endogname'"' ///
        `"`exog' `inst'"' ///
        `"`exogname' `instname'"' ///
        `"`touse2'"' ///
        "" "" `"`normwt'"'  `"`normN2'"' ///
        `"`timevar'"' `"`tvardelta'"' `"`noconstant'"' `"`hasconstant'"' ///
        `"level(95)"' `"`vcetype'"' `"`vceclustvar'"' `"`vcehac'"'	///
        `"`vcehaclag'"'
   }
   else {
      qui doFirst `"`endog'"' `"`endogname'"' ///
        `"`exog' `inst'"' ///
        `"`exogname' `instname'"' ///
        `"`touse2'"' ///
        "" "" `"`normwt'"'  `"`normN2'"' ///
        `"`timevar'"' `"`tvardelta'"' `"`noconstant'"' `"`hasconstant'"' ///
        `"level(95)"' `"`vcetype'"' `"`vceclustvar'"' `"`vcehac'"'	///
        `"`vcehaclag'"'
   }
   tempname nu2
   matrix `nu2' = e(nu2)
   
   //mata:_fs_vcv(`endog', `endogfs', `instfs', `_group2')
   mata:_fs_vcv()

   // Reduced form and calculate 2SLS
   // This could all be done in one Mata go to improve performance, probably
   qui regress `lhs' `instfs' if `touse' & `group'==1, noconstant
   tempvar _u1
   qui predict `_u1' if `touse', resid
   mata:_2s_vcv()

   local allnames "`endogname' `exogname' _cons"
   *matname beta `endogname' `exogname' "_cons"
   *matrix list beta
   *matrix list V
   matrix b = beta'
   matname b `allnames', c(.)
   matname V `allnames'
   *matrix list se

   // Populate ereturn
   ereturn clear
   ereturn post b V, depname(`lhs') esample(`touse')
   ereturn scalar N1 = `normN1'
   ereturn scalar N2 = `normN2'
   ereturn local title "Two-sample two-stage least squares (TS2SLS) regression"
   ereturn local depvar = "`lhs'"
   ereturn local exogr "`exogname'"
   ereturn local insts "`exogname' `instname'"
   ereturn local instd "`endogname'"
   ereturn local estimator "ts2sls"
   ereturn local command "ts2sls"
   

   // Output results
   disp as txt " "
   disp as txt "Two-sample two-stage least squares (TS2SLS) regression"
   disp as txt " "
   disp as txt "Number of obs, group 1 =  `normN1'"
   disp as txt "Number of obs, group 2 =  `normN2'"
   disp as txt " "
   ereturn display
   disp as txt "Instrumented: `endogname'"
   disp as txt "Instruments: `instname'"
   
   /*
   ts2sls price (mpg length = c.weight##c.weight) headroom, group(group) 
   beta[4,1]
            c1
r1   2291.3394
r2   610.95424
r3  -1418.6874
r4  -153205.72

se[4,1]
           c1
r1  2194.2817
r2  505.43445
r3  1562.9277
r4  139573.28
*/
   /*
   . ts2sls price (mpg = c.weight##c.weight) headroom, group(group) 

beta[3,1]
            c1
r1  -343.87479
r2  -573.90742
r3   15206.705

se[3,1]
           c1
r1  73.661468
r2  413.12677
r3  2457.1873
*/

   // cleaning up a few matrices
   //matrix dir
   matrix drop Z2pZ2 Z2pX2 Sigma_nu
end


// CheckCollin is taken from ivregress.ado
program CheckCollin, sclass
	if _caller() >= 11 {
		local vv : di "version " string(_caller()) ":"
	}
	syntax varlist(ts min=1 max=1) [if] [in] [iw/]	 	///
		[, endog(varlist fv ts) exog(varlist fv ts) 	///
		   inst(varlist fv ts) PERfect NOCONSTANT ]
	marksample touse
	if `"`exp'"' != "" {
		local wgt `"[`weight'=`exp']"'
	}
        local fvops = "`s(fvops)'" == "true" | _caller() >= 11
        local tsops = "`s(tsops)'" == "true" 

        if `fvops' {
                if _caller() < 11 {
                        local vv "version 11:"
                }
		local expand "expand"
		fvexpand `exog' if `touse'
		local exog  "`r(varlist)'"
		fvexpand `inst' if `touse'
		local inst  "`r(varlist)'"
		fvexpand `endog'
		local endog "`r(varlist)'"
	}
	/* Catch specification errors */	
	/* If x in both exog and endog, error out */
	local both : list exog & endog
	foreach x of local both {
		di as err 	///
"`x' included in both exogenous and endogenous variable lists"
		exit 498
	}
	
	if "`perfect'" == "" {
		/* If x in both endog and inst, error out */
		local both : list endog & inst
		foreach x of local both {
			di as err 	///
"`x' included in both endogenous and excluded exogenous variable lists"
			exit 498
		}
	}
	
	/* If x on both LHS and (RHS or inst), error out */
	local both : list varlist & endog
	if "`both'" != "" {
		di as err 	///
		 "`both' specified as both regressand and endogenous regressor"
		exit 498
	}
	local both : list varlist & exog
	if "`both'" != "" {
		di as err 	///
		   "`both' specified as both regressand and exogenous regressor"
		exit 498
	}

	local both : list varlist & inst
	if "`both'" != "" {
		di as err 	///
"`both' specified as both regressand and excluded exogenous variable"
		exit 498
	}

	/* Now check for collinearities */
	//`vv' ///
	//_rmdcoll `varlist' `endog' `exog' `wgt' if `touse', `noconstant'
	local totvarlist  `r(varlist)'
	if "`r(k_omitted)'" == "" {
		local both `r(varlist)'
		local endog : list endog & both
		local exog  : list exog & both
	}
	else {
		local list `r(varlist)'
		local omitted `r(k_omitted)'
		if `omitted' {
			foreach var of local list {
				_ms_parse_parts `var'
				local inendog : list var in endog
				local inexog : list var in exog
				if (`inendog') {
					local endog_keep `endog_keep' `var'
				}
				else {
					local exog_keep `exog_keep' `var'
				}
			}
		}
		else {
			local exog_keep `exog'
			local endog_keep `endog'
		}
		local endog `endog_keep'
		local exog `exog_keep'
	}
	//`vv' ///
	//_rmcoll `inst', `expand' `noconstant'
	local inst `r(varlist)'
	if "`inst'" != "" & "`endog'`exog'" != "" {
		if "`noconstant'"  == "" {
			tempvar tmpcons
			qui gen double `tmpcons' = 1 if `touse'
		}
		else {
			local tmpcons
		}
		if "`perfect'" == "" {
			`vv' ///
			_rmcoll2list, alist(`endog' `exog' `tmpcons') ///
				blist(`inst') ///
				normwt(`exp') touse(`touse')
			local inst `r(blist)'
		}
		else if "`exog'" != "" {   // allowing perfect instruments
			`vv' ///
			_rmcoll2list, alist(`exog' `tmpcons') blist(`inst') ///
				normwt(`exp') touse(`touse')
			local inst `r(blist)'
		}
	}
	sreturn local endog `endog'
	sreturn local exog `exog'
	sreturn local inst `inst'
	sreturn local fvops `fvops'
	sreturn local tsops `tsops'
	
end
   
program define doFirst, eclass
	local vv : di "version " string(_caller()) ":"
	args        endolst    	/*  endogenous regressors
		*/  endonam	/*  endogenous names
		*/  instlst	/*  list of all instrumental variables 
		*/  instnam	/*  all IV's names
		*/  touse	/*  touse sample
		*/  weight	/*  type of weight
		*/  wtexp	/*  user's weight expression 
		*/  normwt	/*  normalized wt variable
		*/  normN	/*  sample size accting for wts
		*/  timevar	/*  -tsset- variable
		*/  tvardelta	/*  -tsset- delta
		*/  nocons	/*  noconstant option 
		*/  hascons	/*  hasconstant option 
		*/  levopt 	/*  CI level
		*/  vcetype	/*  type of VCE
		*/  vceclustvar /*  cluster var, if apropos
		*/  vcehac	/*  HAC kernel
      */  vcehaclag	/*  lags for HAC vce */

   di in gr _newline "First-stage regressions"
	di in smcl in gr     "{hline 23}"
	tempname b1 V1 Omega1 clcnt1 lagused1
	tempvar resid1 touse1
	if "`hascons'`nocons'" == "" {
		tempvar one
		gen byte `one' = 1
	}
   local wtexp2 `wtexp'
	if "`weight'" == "pweight" {
		// if pweights, we're robust; use aweights and doctor
		// up VCE with _iv_vce_wrk
		local wtexp2 : subinstr local wtexp2 "pweight" "aweight"
	}
	tokenize `endolst'
	local i 1
	tempvar endotmp
   tempname _nu2
   while "``i''" != "" {
		_ms_parse_parts ``i''
		if r(omit)==1 {
			local i = `i' + 1
			continue
   }

   qui gen double `endotmp' = ``i'' if `touse'

		`vv' ///
		qui _regress `endotmp' `instlst' `wtexp2' if `touse',	///
			`nocons' `hascons' omitted allbaselevels
		local F1 = e(F)
		local dfm = e(df_m)
		local dfr = e(df_r)
		local rmse = e(rmse)
		local r2 = e(r2)
      local r2a = e(r2_a)
      // We need to keep the rmse from each run
      mat `_nu2' = (nullmat(`_nu2'), `rmse'^2)

		mat `V1' = e(V)
		tempname noomit
		NoOmit `instlst', touse(`touse')
		local omit = `r(omitted)'
		mat `noomit' = r(noomit)
		if "`vcetype'" != "unadj" {
			qui predict double `resid1', resid
			tempname noomitcols
			NoOmit `resid1' `instlst' `one' `normwt', touse(`touse')
			mat `noomitcols' = r(noomitcols)
			local hasfv = `r(hasfv)'
			NoOmit `instlst' `one', touse(`touse')
			local exog_c = `r(noomitted)'
			mata: _iv_vce_wrk("`resid1'",		///
					  "`instlst' `one'",	///
					  "",			///
					  "`touse'",		///
					  "`normwt'",		///
					  "`weight'",		///
					  "`vcetype'",		///
					  "`vceclustvar'",	///
					  "`vcehac'",		///
					  "`vcehaclag'",	///
					  "",			///
					  "",			///
					  "`timevar'",		///
					  "`tvardelta'",	///
					  `hasfv',		///
					  `exog_c',		///
					  0,			///
					  "`Omega1'",		///
					  "`clcnt1'",		///
					  "`lagused1'")
			if `omit' {
				mata: ///
			_add_omitted("tmp","`Omega1'","`noomit'",`omit',1,1,1)
			}
			mat `V1' = `V1'/e(rmse)^2 * `Omega1' * `V1'/e(rmse)^2
			local df : list sizeof instlst
			if "`one'" != "" {
				local `++df'
			}
			mat `V1' = `V1'* `normN' / (`normN'-`df')
		}
		gen byte `touse1' = `touse'
		mat `b1' = e(b)
		local stripe
		foreach x in `:colnames(`b1')' {
			`vv' local pos : list posof "`x'" in instlst
			if `pos' > 0 {
				local stripe `stripe' `:word `pos' of `instnam''
			}
			else {
				local stripe `stripe' _cons			
			}
		}
		`vv' ///
		mat colnames `b1' = `stripe'
		`vv' ///
		mat colnames `V1' = `stripe'
		`vv' ///
		mat rownames `V1' = `stripe'
		eret post `b1' `V1', esample(`touse1') obs(`normN') buildfvinfo

		eret scalar df_r = `dfr'
		if "`vcetype'" != "" {		// test with new VCE
			qui test `instnam'
			eret scalar F = r(F)
			eret scalar df_m = r(df)
		}
		else {
			eret scalar F = `F1'
			eret scalar df_m = `dfm'
		}

		if "`vcetype'" == "robust" | "`vcetype'" == "cluster" {
			eret local vcetype "Robust"
		}
		else if "`vcetype'" == "hac" {
			eret local vcetype "HAC"
		}
		if "`vcetype'" == "cluster" {
			eret local clustvar `clus'
			eret scalar N_clust = `clcnt1'
		}
		eret local depvar `:word `i' of `endonam''
		eret scalar rmse = `rmse'
		eret scalar r2 = `r2'
		eret scalar r2_a = `r2a'
		eret local cmd "ivregress_first"
		_coef_table_header
		di
		_coef_table, level(`level')
		cap drop `resid1'
		cap drop `touse1'
		if "`vcetype'" == "hac" {
			if "`vcehaclag'" == "-1" {
				DispHACVCE "`vcehac'" "opt" "`lagused1'"
			}
			else {		
				DispHACVCE "`vcehac'" "`vcehaclag'" ""
			}
		}
		local i = `i' + 1
		drop `endotmp'
	}
	di
   eret matrix nu2=`_nu2'
end

// Taken from ivregress
program NoOmit, rclass
	syntax [varlist(fv ts default=none)] [,touse(string) exporder(string)]
	if "`varlist'" == "" {
		local hasfv = 0
		local omitted 0 
		local noomitted 0
		return scalar omitted = `omitted'
		return scalar noomitted = `noomitted'
		return scalar hasfv = `hasfv'
		exit
	}
	local hasfv = "`s(fvops)'" == "true"	
	if ("`exporder'" == "") {
		fvexpand `varlist' if `touse'
		local full_list `r(varlist)'
	}
	else {
		local full_list `exporder'
	}
	local cols : word count `full_list'
	tempname noomit noomitcols
	mat `noomit' = J(1,`cols',1)
	local omitted 0
	local noomitted 0
	local i 1
	foreach var of local full_list {
		_ms_parse_parts `var'
		if `r(omit)' {
			local ++omitted	
			mat `noomit'[1,`i'] == 0
			if !`hasfv' {
				local hasfv 1
			}
		}
		else {
			local ++noomitted
			capture assert `noomitcols'[1,1]>0
			if !_rc {
				mat `noomitcols' = `noomitcols'[1,1...],`i'
			}
			else {
				mat `noomitcols' = J(1,1,`i')
			}
		}
		local ++i
	}
	return scalar omitted = `omitted'
	return scalar noomitted = `noomitted'
	if `noomitted' > 0 {
		return matrix noomitcols = `noomitcols'
	}
	return scalar hasfv = `hasfv'
	return matrix noomit = `noomit'
end


version 12

mata:
   void _fs_vcv()
   {
      endog = st_local("endog")
      endogfs = st_local("endogfs")
      instfs = st_local("instfs")
      touse2 = st_local("touse2")
      st_view(endo=0,.,tokens(endog), touse2)
      st_view(X2=0,.,tokens(endogfs), touse2)
      st_view(Z2=0,.,tokens(instfs), touse2)
      n2 = rows(Z2)
      m = cols(Z2)
      nu2 = st_matrix(st_local("nu2"))
      zero_cols = cols(X2)-cols(endo)
      if (zero_cols > 0) nu2 = (nu2, J(1, zero_cols, 0));
      
      //Sigma_nu = nu2'*nu2/(n2 - m)
      Sigma_nu = I(cols(X2)):*nu2
      Z2pZ2 = Z2'*Z2
      Z2pX2 = Z2'*X2
      st_matrix("Sigma_nu", Sigma_nu)
      st_matrix("Z2pZ2", Z2pZ2)
      st_matrix("Z2pX2", Z2pX2)
      //Sigma_nu
   }
end
mata:
   void _2s_vcv()
   {
      Sigma_nu = st_matrix("Sigma_nu")
      Z2pZ2 = st_matrix("Z2pZ2")
      Z2pX2 = st_matrix("Z2pX2")
      n2l = st_local("normN2")
      n1l = st_local("normN1")

      // Bring in instrument for Z1, which includes controls
      touse2 = st_local("touse2")
      touse1 = st_local("touse1")
      instfs = st_local("instfs")
      lhs = st_local("lhs")
      _u1 = st_local("_u1")
      st_view(Z2=0,.,tokens(instfs), touse2)
      st_view(Z1=0,.,tokens(instfs), touse1)
      st_view(y1=0,.,tokens(lhs), touse1)
      st_view(u1=0,.,_u1, touse1)
      n1 = rows(y1)
      n2 = rows(Z2)
      m = cols(Z2)
      _alpha = n1/n2
      Xhat1 = Z1*invsym(Z2pZ2)*Z2pX2
      beta = invsym(Xhat1'*Xhat1)*Xhat1'*y1
      sigma11 = u1'*u1/(n1 - m)
      V = invsym(Z2pX2'*invsym((sigma11 + _alpha*beta'*Sigma_nu*beta)*Z2pZ2)*Z2pX2)
      se=sqrt(diagonal(V))
      st_matrix("beta", beta)
      st_matrix("V", V)
      st_matrix("se", se)
   }
end

exit
