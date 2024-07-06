{smcl}
{* *! version 1.0.3  1 Mar 2010}{...}
{cmd:help ts2sls} 

{title:Title}

{p2colset 5 12 14 2}{...}
{p2col :{hi:ts2sls} {hline 2}}Two-sample two-stage least squares (TS2SLS) regression{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 11 2}
{cmd:ts2sls} {y (x = z)} {cmd:=} {ifin} 
[{cmd:,} {it:group(group_var) [noconstant]}]

{title:Description}

Stata program to calculate two-sample two-stage least squares (TS2SLS) estimates. 
Math is based on Inoue and Solon (2005), although variable names more closely follow the shorter version published as Inoue and Solon (2010).

{title:Examples}

{phang}{cmd: # Install ts2sls ado From Github Olah Data Semarang (timbulwidodostp)}

{phang}{cmd:. net install ts2sls, from("https://raw.githubusercontent.com/timbulwidodostp/ts2sls/main/ts2sls") replace}

{phang}{cmd: # Use (Open) File Input From Github Olah Data Semarang (timbulwidodostp)}

{phang}{cmd:. import excel "https://raw.githubusercontent.com/timbulwidodostp/ts2sls/main/ts2sls/ts2sls.xlsx", sheet("Sheet1") firstrow clear}

{phang}{cmd:. # Test baseline: one instrument, one exogenous regressor}

{phang}{cmd:. ts2sls price (mpg = headroom) weight, group(group)}

{phang}{cmd:. # Test multiple instruments}

{phang}{cmd:. ts2sls price (mpg = c.weight##c.weight) headroom, group(group)}

{title:Authors}

Timbul Widodo
Olah Data Semarang
WA : +6285227746673 (085227746673)
Receive Statistical Analysis Data Processing Services Using
SPSS, AMOS, LISREL, Frontier 4.1, EVIEWS, SMARTPLS, STATA
DEAP 2.1, ETC

{title:Also see}
Olah Data Semarang
WA : +6285227746673 (085227746673)
Receive Statistical Analysis Data Processing Services Using
SPSS, AMOS, LISREL, Frontier 4.1, EVIEWS, SMARTPLS, STATA
DEAP 2.1, ETC
{psee}
{p_end}
