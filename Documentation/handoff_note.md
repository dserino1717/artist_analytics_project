Handoff Note

This Alteryx pipeline pulls setlists from [setlist.fm](http://setlist.fm)’s API and album tracklists  from MusicBrainz API, then models them in Snowflake, then gets connected to two Tableau dashboards.

## **How to refresh**

1. **Pull setlists:** run `Music API Workflow.yxmd.` Register for and save a setlist.fm key in a local key file it reads, and do not paste it into the workflow. Output: `unclean_setlist_data.csv`.  
2. **Pull albums and tracks:** run `MusicBrainz API Workflow.yxmd`. You can adjust the user-agent header to your own scenario. Make sure the throttles are very low so it doesn’t return a 503 error. Outputs: the release-groups and tracks CSVs.  
3. **Load raw tables:** in Snowflake, load `DS_SETLIST_DATA_RAW`, `DS_RELEASE_GROUPS_RAW` and `DS_TRACKS_RAW` by creating a new table with each.  
4. **Rebuild the model:** run the DDL/DML script top to bottom (`DS_ARTIST` → `DS_VENUE` → `DS_ALBUM` → `DS_SONG` → `DS_SHOW` → `DS_SONG_PERFORMANCE`), then the check queries at the end.  
5. **Refresh Tableau:** refresh the Snowflake connection and republish both dashboards to the server.

## **What to watch out for**

* **Rate limits:** setlist.fm allows about 2 calls/second and 1,440/day (the workflow throttles to 60/minute and retries 429s). MusicBrainz allows 1/second and reports "server busy" quite a lot even if the throttle is set to less than 1/second, so make sure the throttle rate is quite low (around 2-6 records/min).  
* **User-logged data:** recent shows may not be logged yet. Joint tours sit under separate artist entries: Kendrick’s 2025 Grand National Tour with SZA is missing, which affects the days to road numbers.  
* **Not every setlist is a concert:** TV tapings, pop-ups and festival sets are logged too. I used a tour-show rule (tour name exists and 15+ songs) wherever only full shows should count.  
* **Song matching:** titles are matched after a normalization that happens with the song key, and about 85% of songs played match a core album. setlist.fm labels collaborations and side projects as covers, so some songs labeled as Covers may not actually be so. 

## **What I'd build next**

* **Automate the load:** write Alteryx output straight to Snowflake and schedule a weekly run instead of manually uploading.  
* **Add demand and financial data:** ticket prices (maybe through Ticketmaster Discovery API) and listener counts (using [Last.fm](http://Last.fm) API) to show whether new-album shows sell as well as catalogue-heavy ones.  
* **Routing map:** Show a map using MAKELINE functions that draws out an artists tour to see where more efficient routing is possible.  
* **Grow the roster:** adding an artist only needs their MBID.

