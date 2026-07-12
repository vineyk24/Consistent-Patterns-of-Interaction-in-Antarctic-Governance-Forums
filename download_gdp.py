"""
download_gdp.py
Run this locally to download World Bank GDP data for ATCM/CCAMLR parties.

Usage:
    pip install wbgapi pandas
    python download_gdp.py

Output:
    gdp_atcm_ccamlr.csv  — tidy CSV with columns: country, iso3, year, gdp_current_usd
    gdp_matrix.csv        — wide-format matrix (rows = years, cols = country names)
"""

import wbgapi as wb
import pandas as pd
import numpy as np

# --- All state actors appearing in ATCM and/or CCAMLR networks ---
# Maps the name used in your MATLAB code to the ISO3 code used by the World Bank
COUNTRY_MAP = {
    # Original 12 signatories
    'Argentina':        'ARG',
    'Australia':        'AUS',
    'Belgium':          'BEL',
    'Chile':            'CHL',
    'France':           'FRA',
    'Japan':            'JPN',
    'New Zealand':      'NZL',
    'Norway':           'NOR',
    'South Africa':     'ZAF',
    'United Kingdom':   'GBR',
    'United States':    'USA',
    'Russian Federation': 'RUS',  # USSR pre-1991 — handled below

    # Other Consultative Parties (ATCM)
    'Brazil':           'BRA',
    'Bulgaria':         'BGR',
    'Canada':           'CAN',
    'China':            'CHN',
    'Czechia':          'CZE',
    'Ecuador':          'ECU',
    'Finland':          'FIN',
    'Germany':          'DEU',
    'India':            'IND',
    'Italy':            'ITA',
    'Netherlands':      'NLD',
    'Peru':             'PER',
    'Poland':           'POL',
    'Rep. Korea':       'KOR',
    'Romania':          'ROU',
    'Spain':            'ESP',
    'Sweden':           'SWE',
    'Turkey':           'TUR',
    'Ukraine':          'UKR',
    'Uruguay':          'URY',

    # Non-Consultative Parties / other ATCM participants
    'Malaysia':         'MYS',
    'Monaco':           'MCO',
    'Portugal':         'PRT',
    'Venezuela':        'VEN',
    'Colombia':         'COL',
    'Pakistan':         'PAK',
    'Guatemala':        'GTM',
    'Belarus':          'BLR',
    'Cuba':             'CUB',
    'Denmark':          'DNK',
    'Papua New Guinea': 'PNG',
    'Switzerland':      'CHE',
    'Austria':          'AUT',
    'Hungary':          'HUN',
    'Estonia':          'EST',
    'Slovakia':         'SVK',
    'Slovenia':         'SVN',
    'Iceland':          'ISL',
    'Kazakhstan':       'KAZ',

    # CCAMLR-specific members
    'Namibia':          'NAM',
    'Panama':           'PAN',
    'Mauritius':        'MUS',
    'Vanuatu':          'VUT',
    'Cook Islands':     'COK',  # May not be in WB dataset
}

# EU GDP — fetch separately
EU_CODE = 'EUU'  # World Bank code for European Union

def main():
    print("Downloading GDP data from World Bank (indicator NY.GDP.MKTP.CD)...")
    
    # Fetch all country codes
    iso3_codes = list(COUNTRY_MAP.values()) + [EU_CODE]
    
    # Download GDP (current US$) for 1960-2024
    try:
        df = wb.data.DataFrame(
            'NY.GDP.MKTP.CD',
            economy=iso3_codes,
            time=range(1960, 2025),
            labels=True,
            columns='time'
        )
    except Exception as e:
        print(f"wbgapi approach failed: {e}")
        print("Trying alternative approach with pandas_datareader...")
        # Fallback: direct API call
        import urllib.request
        import json
        
        all_data = []
        for name, iso3 in {**COUNTRY_MAP, 'European Union': EU_CODE}.items():
            url = (f"https://api.worldbank.org/v2/country/{iso3}/"
                   f"indicator/NY.GDP.MKTP.CD?date=1960:2024&format=json&per_page=100")
            try:
                with urllib.request.urlopen(url) as resp:
                    data = json.loads(resp.read())
                    if len(data) > 1 and data[1]:
                        for entry in data[1]:
                            if entry['value'] is not None:
                                all_data.append({
                                    'country': name,
                                    'iso3': iso3,
                                    'year': int(entry['date']),
                                    'gdp_current_usd': float(entry['value'])
                                })
            except Exception as e2:
                print(f"  Warning: could not fetch {name} ({iso3}): {e2}")
        
        df_tidy = pd.DataFrame(all_data)
        df_tidy = df_tidy.sort_values(['country', 'year']).reset_index(drop=True)
        
        # Save tidy format
        df_tidy.to_csv('gdp_atcm_ccamlr.csv', index=False)
        print(f"Saved {len(df_tidy)} rows to gdp_atcm_ccamlr.csv")
        
        # Create wide matrix
        df_wide = df_tidy.pivot(index='year', columns='country', values='gdp_current_usd')
        df_wide.to_csv('gdp_matrix.csv')
        print(f"Saved wide matrix to gdp_matrix.csv")
        return
    
    # Process wbgapi output into tidy format
    df = df.reset_index()
    
    # Melt to long format
    year_cols = [c for c in df.columns if c.startswith('YR')]
    df_long = df.melt(
        id_vars=['economy', 'Country'],
        value_vars=year_cols,
        var_name='year_raw',
        value_name='gdp_current_usd'
    )
    df_long['year'] = df_long['year_raw'].str.replace('YR', '').astype(int)
    df_long = df_long.rename(columns={'economy': 'iso3', 'Country': 'country'})
    df_long = df_long[['country', 'iso3', 'year', 'gdp_current_usd']]
    df_long = df_long.dropna(subset=['gdp_current_usd'])
    df_long = df_long.sort_values(['country', 'year']).reset_index(drop=True)
    
    # Save tidy format
    df_long.to_csv('gdp_atcm_ccamlr.csv', index=False)
    print(f"Saved {len(df_long)} rows to gdp_atcm_ccamlr.csv")
    
    # Create wide matrix (years as rows, countries as columns)
    df_wide = df_long.pivot(index='year', columns='country', values='gdp_current_usd')
    df_wide.to_csv('gdp_matrix.csv')
    print(f"Saved wide matrix to gdp_matrix.csv")
    
    # --- Handle USSR/Russia ---
    # The World Bank has Russia (RUS) from 1988 onwards.
    # For 1961-1987, you may need to use USSR GDP estimates.
    # One approach: use the Maddison Project Database or manually input USSR figures.
    rus_years = df_long[df_long['iso3'] == 'RUS']['year']
    if len(rus_years) > 0:
        print(f"\nNote: Russia GDP available from {rus_years.min()} to {rus_years.max()}")
        print("For 1961-1987 (USSR era), GDP will need manual interpolation or")
        print("Maddison Project data. The MATLAB code handles missing values by")
        print("setting fitness = 1 for those edges (reverting to endogenous model).")
    
    # Summary
    print("\n--- Coverage summary ---")
    for name, iso3 in sorted(COUNTRY_MAP.items()):
        subset = df_long[df_long['iso3'] == iso3]
        if len(subset) > 0:
            print(f"  {name:25s}  {subset['year'].min()}-{subset['year'].max()}  ({len(subset)} years)")
        else:
            print(f"  {name:25s}  NO DATA")


if __name__ == '__main__':
    main()
