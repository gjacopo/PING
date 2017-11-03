/** 
## _DSTEST31 {#sas_dstest31}
Test dataset #31.

	%_dstest31;
	%_dstest31(lib=, _ds_=, verb=no, force=no);

### Contents
The following table is stored in `_dstest31`:
geo | value | unit
----|-------|-----
 BE |  0    | EUR
 AT |  0.1  | EUR
 BG |  0.2  | NAC
 LU |  0.3  | EUR
 FR |  0.4  | NAC
 IT |  0.5  | EUR

### Arguments
* `lib` : (_option_) output library; default: `lib` is set to `WORK`;
* `verb` : (_option_) boolean flag (`yes/no`) for verbose mode; default: `no`;
* `force` : (_option_) boolean flag (`yes/no`) set to force the overwritting of the
	test dataset whenever it already exists; default: `no`. 

### Returns
`_ds_` : (_option_) the full name (library+table) of the dataset `_dstest31`. 
	
### Example
To create dataset #31 in the `WORK`ing directory and print it, simply launch:
	
	%_dstest31;
	%ds_print(_dstest31);

### See also
[%_dstestlib](@ref sas_dstestlib).
*/ /** \cond */

%macro _dstest31(lib=, _ds_=, verb=no, force=no);
 	%local _dsn _ilib;
	%let _dsn=&sysmacroname;
	%_dstestlib(&_dsn, _lib_=_ilib);

	%if %macro_isblank(_ilib) or &force=yes %then %do;	
		%if &verb=yes %then %put dataset &_dsn is created ad-hoc;
		%let _ilib=WORK;
		DATA &_ilib..&_dsn;
			geo='BE'; value=0; unit='EUR'; output;
			geo='AT'; value=0.1; unit='EUR'; output;
			geo='BG'; value=0.2; unit='NAC'; output;
			geo='LU'; value=0.3; unit='EUR'; output;
			geo='FR'; value=0.4; unit='NAC'; output;
			geo='IT'; value=0.5; unit='EUR'; output;
		run;
	%end;
	%else %do;
		%if &verb=yes %then %put dataset &_dsn already exists in library &_ilib;
	%end;

	%if %macro_isblank(lib) %then 	%let lib=WORK;

	%if "&lib"^="&_ilib" %then %do;
		/* %ds_merge(&_dsn, &_dsn, lib=&_ilib, olib=&lib); */
		DATA &lib..&_dsn;
			set &_ilib..&_dsn;
		run; 
		%if &_ilib=WORK %then %do;
			%work_clean(&_dsn);
		%end;
	%end;

	%if not %macro_isblank(_ds_) %then 	%do;
		data _null_;
			call symput("&_ds_", "&lib..&_dsn");
		run; 
	%end;		

%mend _dstest31;

%macro _example_dstest31;
	%if %symexist(G_PING_ROOTPATH) EQ 0 %then %do; 
		%if %symexist(G_PING_SETUPPATH) EQ 0 %then 	%let G_PING_SETUPPATH=/ec/prod/server/sas/0eusilc; 
		%include "&G_PING_SETUPPATH/library/autocall/_setup_.sas";
		%_default_setup_;
	%end;
	
	%_dstest31(lib=WORK);
	%put Test dataset is generated in WORK library as: _dstest31;
	%ds_print(_dstest31);

	%work_clean(_dstest31);
%mend _example_dstest31;

/*
options NOSOURCE MRECALL MLOGIC MPRINT NOTES;
%_example_dstest31; 
*/

/** \endcond */
