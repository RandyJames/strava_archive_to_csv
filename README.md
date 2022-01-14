# strava_archive_to_csv
Generate a .csv of GPS data included in the Strava extract that can be used to link against the activities.csv

Started with [this article](https://www.tableau.com/about/blog/2019/3/how-make-art-out-your-strava-activity-data-tableau-104639) about visualizing Strava data.

But instead of using the API, all of the GPS data is extracted from files included with the Strava extract.

# Usage
```
bundle install
bundle exec ruby strava_archive_to_csv.rb --dir ~/Downloads/export_784456/ --year 2021
```
Or export all years
```
bundle exec ruby strava_archive_to_csv.rb --dir ~/Downloads/export_784456/ --year 0
```

# Tableau
The result is a .csv that can be linked to the activities.csv on the activitiy_id

Here is a [Tableau workbook](https://public.tableau.com/app/profile/randy.james/viz/StravaAllData/2021) with all of my data.  The calculations from the workbook were all borrowed from this [blog article](https://www.tableau.com/about/blog/2019/3/how-make-art-out-your-strava-activity-data-tableau-104639).

# TODO
I manually unzipped all of the .fit.gz files and haven't tested the code to unzip them yet.  So for now, manually unpack the .fit.gz files in the Strava archive before running.