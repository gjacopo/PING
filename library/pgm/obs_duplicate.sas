/** 
## obs_duplicate {#sas_obs_duplicate}
Extract duplicated/unique observations from a given dataset.

~~~sas
	%obs_duplicate(idsn, id=, dupdsn=, unidsn=, select=, ilib=WORK, olib=WORK);
~~~

### Arguments
* `idsn` : a dataset reference;
* `id` : (_option_) list of identifying/key variables of `idsn` ; 
* `ilib` : (_option_) name of the input library; by default: empty, _i.e._ `WORK` is used;
* `olib` : (_option_) name of the output library; by default: empty, _i.e._ `WORK` is also used.

### Returns
* `dupdsn` : name of the output dataset with duplicated observations; it will contain the selection 
	operated on the original dataset;
* `unidsn` : name of the output dataset with unique observations.

### Examples

### References
1. Note on ["FIRST. and LAST. variables"](http://www.albany.edu/~msz03/epi514/notes/first_last.pdf).
2. Note on ["Working with grouped observations"](http://www.cpc.unc.edu/research/tools/data_analysis/sastopics/bygroups).
3. ["How the DATA step identifies BY groups"](http://support.sas.com/documentation/cdl/en/lrcon/62955/HTML/default/viewer.htm#a000761931.htm).
4. Cai, E. (2015): ["Getting all Duplicates of a SAS data set"](https://chemicalstatistician.wordpress.com/2015/01/05/getting-all-duplicates-of-a-sas-data-set/).
5. Cai, E. (2015): ["Separating unique and duplicate observations using PROC SORT in SAS 9.3 and newer versions"](https://chemicalstatistician.wordpress.com/2015/04/10/separating-unique-and-duplicate-variables-using-proc-sort-in-sas-9-3-and-newer-versions/).

### See also
[%obs_select](@ref sas_obs_select), [%ds_isempty](@ref sas_ds_isempty), [%ds_check](@ref sas_ds_check),
[%sql_clause_by](@ref sas_sql_clause_by), [%sql_clause_as](@ref sas_sql_clause_as), [%ds_select](@ref sas_ds_select), 
[SELECT ](http://support.sas.com/documentation/cdl/en/proc/61895/HTML/default/viewer.htm#a002473678.htm).
*/ /** \cond */

/* credits: gjacopo */

%macro obs_duplicate(idsn		/* Input dataset 															(REQ) */
					, id=		/* Dimensions taken into account when identifying identical observations	(OPT) */
					, dupdsn=	/* Output dataset of duplicated observations 								(OPT) */
					, unidsn=	/* Output dataset of unique observations									(OPT) */
					, ilib=		/* Name of the input library 												(OPT) */
					, olib=		/* Name of the output library 												(OPT) */
					);
	%local _mac;
	%let _mac=&sysmacroname;
	%macro_put(&_mac);

	/************************************************************************************/
	/**                                 checkings/settings                             **/
	/************************************************************************************/

	%local _vars;
	%let _vars=;

	/* IDSN/ILIB: check  the input dataset */
	%if %macro_isblank(ilib) %then 	%let ilib=WORK;

	%if %error_handle(ErrorInputDataset, 
			%ds_check(&idsn, lib=&ilib) EQ 1, mac=&_mac,		
			txt=!!! Input dataset %upcase(&idsn) not found !!!) %then
		%goto exit;

	/* ID: set/check */
	%ds_contents(&idsn, _varlst_=_vars, lib=&ilib);

	%if %macro_isblank(id) %then 		%let id=&_vars;
	%else %if %error_handle(ErrorInputParameter, 
			%macro_isblank(%list_difference(&id, &_vars)) NE 1, mac=&_mac,		
			txt=!!! Input variables in &id not found in input dataset &idsn !!!) %then
		%goto exit;

	/* OLIB: set default  */
	%if %macro_isblank(olib) %then 	%let olib=WORK/*&ilib*/;

	/* DUPDSN: default output dataset */
	%if not %macro_isblank(dupdsn) %then %do;
		%if %error_handle(WarningOutputDataset, 
				%ds_check(&dupdsn, lib=&olib) EQ 0, mac=&_mac,		
				txt=! Output dataset of duplicates %upcase(&dupdsn) already exists: will be replaced !, 
				verb=warn) %then
			%goto warning1;
		%warning1:
	%end;

	/* UNIDSN: default output dataset */
	%if not %macro_isblank(unidsn) %then %do;
		%if %error_handle(WarningOutputDataset, 
				%ds_check(&unidsn, lib=&olib) EQ 0, mac=&_mac,		
				txt=! Output dataset of unique values %upcase(&unidsn) already exists: will be replaced !, 
				verb=warn) %then
			%goto warning2;
		%warning2:
	%end;
	
	/* DUPDSN and UNIDSN: blank for both parameters */
	%if %error_handle(WarningInputParameter,
	    %macro_isblank(unidsn) and %macro_isblank(dupdsn), mac = &_mac,
	    txt=! No output will be produced as both DUPDSN and UNIDSN are blank !,
	    verb=warn) %then
	      %goto warning3;
	    %warning3:
	%end ;

	/************************************************************************************/
	/**                                 actual computation                             **/
	/************************************************************************************/

	%local _id_last
		_nid;

	%let _nid=%list_length(&id);
	%let _id_last=%scan(&id, &_nid);

	%local _dsn;
	%let _dsn=TMP&_mac;

	%let _FORCE_SORT_=NO;

	%if %sysevalf(&sysver >= 9.3) or "&_FORCE_SORT_"="YES" %then %do;
		PROC SORT
			DATA = &ilib..&idsn
			%if not %macro_isblank(dupdsn) %then %do;
		    	OUT = &olib..&dupdsn
			%end;
			%if not %macro_isblank(unidsn) or not %macro_isblank(select) %then %do;
				UNIQUEOUT = &olib..&unidsn
			%end;
		    NOUNIQUEKEY;
		    BY &id;
		run;
	%end;

	PROC SORT 
		DATA=&ilib..&idsn 
		OUT=&_dsn;
		BY &id;
	run;

	/* create table with FIRST/LAST variables */
	DATA &_dsn;
		SET &_dsn;
		BY &id;
		first_&_id_last = first.&_id_last;
		last_&_id_last = last.&_id_last;
		/* LABEL
			first_&_id_last = 'first.&_id_last'
			last_&_id_last = 'last.&_id_last'; */
	run;

	/* create table of unique values */
	%if not %macro_isblank(unidsn) %then %do;
		PROC SQL;
			CREATE TABLE &olib..&unidsn(DROP=first_&_id_last last_&_id_last) AS
			SELECT * /* &_dimensions, * */
			FROM &_dsn
			WHERE (first_&_id_last=1 and last_&_id_last=1) ;
		run;
	%end;
	
	/* create table of duplicates */
	%if not %macro_isblank(dupdsn) %then %do;
		PROC SQL;
			CREATE TABLE &olib..&dupdsn(DROP=first_&_id_last last_&_id_last)  AS
			SELECT * /* &_dimensions, * */
			FROM &_dsn
			WHERE (first_&_id_last=0 or last_&_id_last=0) ;
		run;
	%end;

	%work_clean(&_dsn);

	%exit:
%mend obs_duplicate;


%macro _example_obs_duplicate;
	%if %symexist(G_PING_SETUPPATH) EQ 0 %then %do; 
        %if %symexist(G_PING_ROOTPATH) EQ 0 %then %do;	
			%put WARNING: !!! PING environment not set - Impossible to run &sysmacroname !!!;
			%put WARNING: !!! Set global variable G_PING_ROOTPATH to your PING install path !!!;
			%goto exit;
		%end;
		%else %do;
        	%let G_PING_SETUPPATH=&G_PING_ROOTPATH./PING; 
        	%include "&G_PING_SETUPPATH/library/autoexec/_setup_.sas";
        	%_default_setup_;
		%end;
    %end;

	 data test;
		geo="BE"; time=2015; hhtyp="HH_NDCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=9.6356617344; output;
		geo="BE"; time=2015; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=16.30637264; output;
		geo="BE"; time=2016; hhtyp="A1_DCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=15.256596775; output;
		geo="BE"; time=2015; hhtyp="A_GE2_DCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=13.631088356; output;
		geo="BE"; time=2015; hhtyp="A_GE2_NDCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=7.5261077037; output;
		geo="BE"; time=2015; hhtyp="HH_DCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=13.755266381; output;
		geo="BE"; time=2015; hhtyp="HH_NDCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=9.2194453624; output;
		geo="BE"; time=2017; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC"; ivalue=14.101123997; output;
		geo="BE"; time=2015; hhtyp="A1_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=28.173894694; output;
		geo="BE"; time=2015; hhtyp="A_GE2_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=17.076805818; output;
		geo="BE"; time=2015; hhtyp="A_GE2_NDCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=8.2945434449; output;
		geo="BE"; time=2015; hhtyp="HH_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=18.040964168; output;
		geo="BE"; time=2015; hhtyp="HH_NDCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=9.2040946555; output;
		geo="BE"; time=2016; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC"; ivalue=25.95019727; output;
		geo="BE"; time=2015; hhtyp="A1_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=17.074086034; output;
		geo="BE"; time=2015; hhtyp="A_GE2_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=6.0416912031; output;
		geo="BE"; time=2015; hhtyp="A_GE2_NDCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=5.5593306824; output;
		geo="EA18"; time=2015; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC"; ivalue=14.101123997; output;
		geo="EA18"; time=2015; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=18.298578708; output;
		geo="EA18"; time=2015; hhtyp="A1_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=28.173894694; output;
		geo="EA18"; time=2015; hhtyp="A1_DCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=25.232276752; output;
		geo="EA18"; time=2015; hhtyp="A_GE2_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=17.076805818; output;
		geo="EA18"; time=2015; hhtyp="A_GE2_DCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=11.35293719; output;
		geo="EA18"; time=2015; hhtyp="A_GE2_NDCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=8.2945434449; output;
		geo="EA18"; time=2015; hhtyp="A_GE2_NDCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=6.4145051183; output;
		geo="EA18"; time=2015; hhtyp="HH_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=18.040964168; output;
		geo="EA18"; time=2015; hhtyp="HH_DCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=12.842222186; output;
		geo="EA18"; time=2015; hhtyp="HH_NDCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=9.2040946555; output;
		geo="EA18"; time=2015; hhtyp="HH_NDCH"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=10.075303418; output;
		geo="EA19"; time=2015; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC"; ivalue=14.101123997; output;
		geo="EA19"; time=2015; hhtyp="A1"; indic_il="LIP_MD60"; unit="PC_POP"; ivalue=18.382338974; output;
		geo="EA19"; time=2015; hhtyp="A1_DCH"; indic_il="LIP_MD60"; unit="PC"; ivalue=28.173894694; output;
	run;

	%obs_duplicate(test, dim=geo time hhtyp indic_il, unidsn=unidsn, dupdsn=dupdsn, 
		ilib=WORK, olib=WORK);

	%exit:
%mend _example_obs_duplicate;

/* Uncomment for quick testing
options NOSOURCE MRECALL MLOGIC MPRINT NOTES;
%_example_obs_duplicate; 
*/

/** \endcond */
 