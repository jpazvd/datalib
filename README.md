# DATALIB

**`datalib` treats survey microdata as a versioned asset** — the operational
equivalent, for household surveys, of what version control did for code.

Research teams treat code as a versioned asset: committed, reviewed,
integrity-checked, citable. Data rarely gets the same discipline — microdata
typically lives on a shared drive, in a folder named by whoever last copied it,
with a citation buried in an e-mail thread. Yet a nationally representative
survey costs millions of dollars to field, while a re-analysis costs orders of
magnitude less: the highest-leverage intervention in empirical research is not
collecting more surveys but **sustaining more analyses per survey**.

`datalib` makes that possible by encoding the archive discipline as executable
code rather than undocumented researcher conventions. It organizes microdata in
the **IHSN / World Bank Microdata Library** folder standard — original **MASTER**
files (`CCC_YYYY_SSSS_vNN_M`, immutable) kept strictly separate from
**HARMONIZED** adaptations (`..._vNN_A_CLCT`) — and provides a unified interface
to deposit, discover, load, and validate survey-versions across countries and
vintages, with DDI/Dublin Core metadata generated at deposit time. Originally
developed in the context of the World Bank's microdata workflows and since used
at UNICEF and other institutions, the design is **institution-agnostic**: it fits
research labs, statistical agencies, microdata custodians, and multi-investigator
teams alike — anyone who believes data deserves the same versioned, auditable
handling that code already gets.

## Quick start

`datalib` organizes survey microdata in the **IHSN / World Bank Microdata Library**
folder taxonomy and gives you the same three verbs in **Stata, Python, and R** —
with identical option names and values:

| | get (load by coordinates) | put (deposit, IHSN-enforced) | check (validate archive) |
|---|---|---|---|
| **Stata** | `datalib, country(BRA) year(2019) survey(MICS) clear` | `_dtlb_put, country(BRA) year(2023) survey(SAEB)` | `_dtlb_check, path("$datalib")` |
| **Python** | `datalib.get(country="BRA", year=2019, survey="MICS")` | `datalib.put(df, country="BRA", year=2023, survey="SAEB")` | `datalib.check()` |
| **R** | `dl_get(country = "BRA", year = 2019, survey = "MICS")` | `dl_put(df, country = "BRA", year = 2023, survey = "SAEB")` | `dl_check()` |

`put` is where the standard is enforced: it builds the IHSN folder skeleton, writes
DDI-Codebook + Dublin Core + codebook metadata, keeps **MASTER** (original, immutable)
and **HARMONIZED** (adaptations) in separate version folders, and validates the result.

**Install**

```stata
* Stata
net install datalib, from(https://raw.githubusercontent.com/jpazvd/datalib/main/)
```
```bash
# Python (from a clone)
pip install -e python/
```
```r
# R (from a clone; packaging in progress)
source("R/R/datalib.R")
```

**Learn by running:** self-contained, temp-folder-safe examples in
[`examples/`](examples/) — one per language. The full specification is in
[`00_documentation/taxonomy.md`](00_documentation/taxonomy.md).

## Scripts

Shell scripts in `scripts/` automate common workflows. Run them from the repo root:

| Script                 | Purpose                                                  |
|------------------------|----------------------------------------------------------|
| `scripts/pull-data.sh` | Pull `.dta.zip` archives from Git LFS and unzip locally  |

### Data setup (`pull-data.sh`)

`.dta` files are **not stored in git** — they are unzipped locally from `.dta.zip` archives tracked in Git LFS. After cloning or whenever data files are missing/outdated:

```bash
bash scripts/pull-data.sh
```

This pulls the LFS archives and unzips them into `01_data/011_stata/`. The `.dta` files are gitignored and never committed; only the `.dta.zip` files are versioned.

## Data workflow: datalib
The storage of data and other materials in Datalib is organized by country. One folder has been created for each country. The folder name is the ISO 3-letter code for each country, as spelled in the WDI and available through the wbopendata command in Stata3. As some datasets are multi-country, the following folders were also created:
* WLD: for datasets containing data from countries belonging to more than one region
* HLT: for datasets containing data from countries belonging to more than one country from HLT
If necessary, folders for other regions can be created here too. One folder will then be created for each survey. This folder name will be as follows:

CCC_YYYY_SSSS

where
* CCC = WDI country code (3 letters) (capitalized)
* YYYY = survey year (4 digits); we use the year when data collection started
* SSSS = survey acronym (e.g., MICS, DHS, LSMS, CWIQ, HBS, etc) (capitalized)

For instance, the folder for the HBS 2005 from Albania will be ALB_2005_HBS. For multi-country datasets, CCC will be WLD (World) or ECA.
One survey may have more than one version of the dataset. So under the survey folder, we will have as many sub-folders as we have versions. Even when we only have one version, we will create the sub-folder. The sub-folder name will identify the version.
The subfolder name will be as follows:

CCC_YYYY_SSSS_ vNN _M_vNN_A_HHHH

Where
* CCC = WDI country code (3 letters) (capitalized)
* YYYY = survey year; we use the year when data collection started
* SSSS = survey acronym (e.g., MICS, DHS, LSMS, CWIQ, HBS, etc) (capitalized)
* vNN_M = the “M” comes from Master file. The Master file is the full dataset, typically as provided by the country. vNN is the version name; NN is a sequential number; it will always start with 01 and when a newer version is available it should be named v02, then v03 etc. The description of the version will be found in the DDI metadata. Note that when a new version comes, the previous one(s) must be kept too.
* vNN_A_HHHH = “A” for Adaptations, and "CLCT" or “HHHH” for the name of the collection or adaptation. These are often subsets of the data, such as harmonized datasets; in our case, for now, the adaptions we have are ECAPOV, SILC and HOI. This part of the code will only appear when it’s not the original data, and it will be the name of the source folder where this data is being stored. The vNN follows the same rule as the numbering for original data, but this one refers for the version of the adaptation.
For instance, the harmonized dataset produced by PREM for the ECAPOV project using the Tajikistan Living Standards Survey of 2009 would be named “TJK_2009_TLSS_v01_M_v01_A_ECAPOV” (See figure 1). This sub-folder name is where we will store the Nesstar file (the Nesstar filename will be the same as the name of the folder), as well as the DDI and the Dublin Core XML files. All other materials (data in Stata or other format, documents, programs) will be stored in sub-folders as described below.

In the master version folder (in the case described, TJK_2009_TLSS_v01_M), we will create the following folders:

* “Data” to store the data files.
  * “Data\Original”: Under “Data” one sub-folder “Original” is created to store the dataset as received. This dataset will always be kept unchanged (i.e. in whatever format we receive it). If necessary, additional sub-folders can be created (for instance, if the original dataset is provided in multiple formats).
  * “Data\Stata”: For every survey, we will store the data in Stata format. This Stata files will be the ones obtained by exporting the microdata from the Nesstar file. The variable/value labels will thus be strictly identical to what we find in the Nesstar file.
  * “Data\Other”: Optionally, we can also save the data files in other formats (e.g., SPSS or ASCII). Again, this will have to correspond exactly to the data stored in the Nesstar file.

* “Doc” to store the document files.
  * “Doc\Questionnaires” to store all questionnaires (in PDF, XLS or other). Sub-folders can be created is needed.
  * “Doc\Reports” to store the survey reports (and related, such as PPT presentations, papers, briefs, etc). Sub-folders can be created is needed.
  * “Doc\Technical” to store all technical documents (code lists, interviewer’s manuals, sampling description, etc) and other materials such as photos, maps, etc. Sub-folders can be created is needed.

* “Programs” to store all programs: data entry, editing, tabulation, analysis. Sub-folders can be created if needed.
Note that all folders will be created, even if we do not have content for them (see Figure 2 for an example using Tajikistan 2009 TLSS).

How to name and organize the do files
For each country (CCC) and each year (YYYY), GMD generates up to four datasets starting from the original survey (see Annex I for further details) using the format:

CCC_YYYY_SurveyName_vnn_M_vmm_A_GMD_i 

where:
* vnn 		(nn=01, 02, … ) stands for the version of the master file;
* vmm 	(mm=01, 02, …) stands for the version of the harmonization, as there can be revisions after the first release;
* i	denotes the specific GMD dataset, and in particular: 
  * i=adult 	    Contains basic information collected for adults in the household;
  * i=children 	    Contains basic information collected for children in the household;
  * i=hhmembers 	Contains basic information collected for hhmembers in the household;
  * i=household 	Contains basic information collected for household;

