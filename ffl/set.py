import json

import pandas as pd
import requests
from pymemcache.client import base
import os

pd.options.mode.chained_assignment = None

endpoint = os.environ.get('endpoint')
port = os.environ.get('port')

# Making API call and storing response
url = 'https://fantasy.premierleague.com/api/bootstrap-static/'
r = requests.get(url)
#print("Status code: ", r.status_code)

# Storing API respons in variable
response_dict = r.json()

# Team id's
teams = response_dict['teams']

team_list = []
for team in teams:
    team_id = {
        team['code']: team['name']
    }
    team_list.append(team_id)

team_dict = {}
for team in team_list:
    team_dict.update(team)

#print(team_dict)

# Position id's
element_types = response_dict['element_types']
#print(element_types)

position_list = []
for element_type in element_types:
    position_id = {
        element_type['id']: element_type['plural_name_short']
    }
    position_list.append(position_id)
#print(position_list)

position_dict = {}
for position in position_list:
    position_dict.update(position)
#print(position_dict)

wanted_features = ['first_name', 'second_name', 'team_code', 'element_type', 'news', 'now_cost', 'total_points', 'minutes',
                   'form',  'value_season', 'points_per_game', 'value_form',
                   'goals_scored', 'assists', 'dreamteam_count', 'clean_sheets',
                   'goals_conceded', 'own_goals', 'penalties_saved', 'penalties_missed',
                   'yellow_cards', 'red_cards', 'saves', 'bonus',
                   'influence', 'creativity', 'threat', 'ict_index', 'selected_by_percent'
                   ]

player_data = response_dict['elements']

# Converting the list of players to a DataFrame
players_df = pd.DataFrame(player_data)
# Choosing only the columns that we want
players_df = players_df[wanted_features]
players_df.head()

# Replacing team_code with team name
players_df = players_df.replace({'team_code': team_dict})

# Replacing id with position
players_df = players_df.replace({'element_type': position_dict})

# Renaming columns
players_df = players_df.rename(
    columns={'team_code': 'team', 'element_type': 'position'})
players_df.head()

# Combining first and last name to one column
players_df['player_name'] = players_df['first_name'].str.cat(
    players_df['second_name'], sep=' ')
#print(players_df['player_name'])

# Removing first_name and second_name columns
players_df = players_df.drop(['first_name', 'second_name'], axis=1)

# Function for creating cell-values


def unavailable(row):
    if row['news'] != '':
        return True
    else:
        return False


# Using function to create new column:
players_df['unavailable'] = players_df.apply(
    lambda row: unavailable(row), axis=1)
players_df.head()


# Rearranging order to get name as the first column
players_df = players_df[['player_name', 'team', 'position', 'unavailable', 'now_cost', 'total_points', 'minutes',
                         'form',  'value_season', 'points_per_game', 'value_form',
                         'goals_scored', 'assists', 'dreamteam_count', 'clean_sheets',
                         'goals_conceded', 'own_goals', 'penalties_saved', 'penalties_missed',
                         'yellow_cards', 'red_cards', 'saves', 'bonus',
                         'influence', 'creativity', 'threat', 'ict_index', 'selected_by_percent'
                         ]]

#print(players_df.head())
# Creating a dataframe for "Top performing players":
most_points = players_df[['player_name', 'team',
                          'position', 'total_points', 'now_cost', 'unavailable']]
most_points = most_points.sort_values(by='total_points', ascending=False)
most_points.head()


# Creating dataframe for ROI-players
roi_players = players_df[['player_name', 'team',
                          'position', 'total_points', 'now_cost', 'unavailable']]
roi_players['roi'] = roi_players.apply(
    lambda row: row.total_points / row.now_cost, axis=1)
roi_players = roi_players.sort_values(by='roi', ascending=False)
#print(roi_players.head())


def choose_team():
    roi_team = []
    total_points = 0
    budget = 1000
    top_performer_limit = 3
    position_dict = {"GKP": 2, "DEF": 5, "MID": 5, "FWD": 3}
    team_dict = {'Man City': 3, 'Liverpool': 3, 'Leicester': 3,
                 'Man Utd': 3, 'Wolves': 3, 'Southampton': 3,
                 'Arsenal': 3, 'Burnley': 3, 'Chelsea': 3,
                 'Spurs': 3, 'Everton': 3, 'Wolves': 3,
                 'Newcastle': 3, 'Aston Villa': 3, 'Norwich': 3,
                 'Watford': 3, 'Crystal Palace': 3, 'Brighton': 3,
                 'Brentford': 3, 'West Ham': 3, 'Leeds': 3}

    # Choosing 2 top performers from the "top players"-dataframe
    selections = {"selections": {"GKP": {}, "DEF": {}, "MID": {}, "FWD": {}}}

    for idx, row in most_points.iterrows():
        if budget >= row.now_cost and len(roi_team) < top_performer_limit and row.unavailable == False and position_dict[row.position] != 0 and team_dict[row.team] != 0:
            roi_team.append(row.player_name)
            #roi_team.append(row.position)
            budget -= row.now_cost  # Deducting cost from budget
            # Deducting position from position dictionary
            position_dict[row.position] -= 1
            team_dict[row.team] -= 1  # Deducting player from team dictionary
            total_points += row.total_points  # adding to point score
            print("Player choosen from 'top players' " + str(row.player_name))

        # Choosing remaining team from "ROI"-dataframe
        else:
            for idx, row in roi_players.iterrows():
                if row.player_name not in roi_team and budget >= row.now_cost and row.unavailable == False and position_dict[row.position] != 0 and team_dict[row.team] != 0:
                    roi_team.append(row.player_name)
                    roi_team.append(row.position)
                    budget -= row.now_cost
                    # Deducting position from position dictionary
                    position_dict[row.position] -= 1
                    # Deducting player from team dictionary
                    team_dict[row.team] -= 1
                    total_points += row.total_points  # adding to point score

                    if row.position == "GKP":
                        selections["selections"]["GKP"].update(
                            {row.player_name: row.team})
                    if row.position == "DEF":
                        selections["selections"]["DEF"].update(
                            {row.player_name: row.team})
                    if row.position == "MID":
                        selections["selections"]["MID"].update(
                            {row.player_name: row.team})
                    if row.position == "FWD":
                        selections["selections"]["FWD"].update(
                            {row.player_name: row.team})

    return json.dumps(selections).encode('utf-8')

def ffl(event, context):
    team = choose_team()
    client = base.Client((endpoint, port))
    client.set('ffl', team)
