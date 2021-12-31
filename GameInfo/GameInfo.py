import os, sys, csv

#arguments received from command line
dirname = os.path.dirname(__file__)
folder_path = dirname + "\\"
csv_path =  folder_path + "stats.csv" #where CSV file is ending
all_files = os.listdir(dirname)


#Initialize lists
CapitalShip_PathList = []
Frigate_PathList = []


#Put path to all CapitalShips and Frigates into 2 lists
for entity in all_files:
    full_path = folder_path + entity
    opened_entity = open(full_path, 'r')
    for i, line in enumerate(opened_entity):
        if (i == 2) and (entity[-17:] != "RaceSelect.entity"):
            if line == 'entityType "CapitalShip"\n':
                CapitalShip_PathList.append(entity)
            elif line == 'entityType "Frigate"\n':
                Frigate_PathList.append(entity)
    opened_entity.close()

csv_file = open(csv_path, 'w', newline='')
csv_writer = csv.writer(csv_file)

#master title list
data = [['Name', 'entityType', 'credit', 'metal', 'crystal', 'slotCount', 'BuildTime', 'MaxHullPoints', 'MaxShieldPoints', 'MaxAntiMatter', 'BaseArmorPoints', 'maxMitigation', 'NumWeapons', 'w1 WeaponClassType', 'w1 DamagePerBank:FRONT', 'w1 DamagePerBank:BACK', 'w1 DamagePerBank:LEFT', 'w1 DamagePerBank:RIGHT', 'w1 Range', 'w1 PreBuffCooldownTime', 'w2 WeaponClassType', 'w2 DamagePerBank:FRONT', 'w2 DamagePerBank:BACK', 'w2 DamagePerBank:LEFT', 'w2 DamagePerBank:RIGHT', 'w2 Range', 'w2 PreBuffCooldownTime', 'w3 WeaponClassType', 'w3 DamagePerBank:FRONT', 'w3 DamagePerBank:BACK', 'w3 DamagePerBank:LEFT', 'w3 DamagePerBank:RIGHT', 'w3 Range', 'w3 PreBuffCooldownTime', 'w4 WeaponClassType', 'w4 DamagePerBank:FRONT', 'w4 DamagePerBank:BACK', 'w4 DamagePerBank:LEFT', 'w4 DamagePerBank:RIGHT', 'w4 Range', 'w4 PreBuffCooldownTime']]
csv_writer.writerows(data)

data = [[]]

#weapons are annoying (only 1 at a time)
def weapons(line_num):
    weapon_data = []
    weapon_data.append(line[line_num + 8][18:-1]) #WeaponClassType
    weapon_data.append(line[line_num + 9][21:-1]) #DamagePerBank:FRONT
    weapon_data.append(line[line_num + 10][20:-1]) #DamagePerBank:BACK
    weapon_data.append(line[line_num + 11][20:-1]) #DamagePerBank:LEFT
    weapon_data.append(line[line_num + 12][21:-1]) #DamagePerBank:RIGHT
    weapon_data.append(line[line_num + 13][7:-1]) #Range
    weapon_data.append(line[line_num + 14][21:-1]) #PreBuffCooldownTime
    
    added_number = 0
    
    added_number = added_number + (int(line[line_num + added_number + 29][14:-1])) #muzzleSounds count
    added_number = added_number + (int(line[line_num + added_number + 32][14:-1])) #hitHull count
    added_number = added_number + (int(line[line_num + added_number + 34][14:-1])) #hitHull count
    
    if (line[line_num + added_number + 35][2:-1]) == 'missileTravelEffectName "Conc_Missile"':
        added_number = added_number + 3
        
    if (line[line_num + added_number + 35][2:-1]) == 'missileTravelEffectName "Proton_Torp"':
        added_number = added_number + 3
    
    return (added_number + 35, weapon_data)

#CapitalShip information
for entity in CapitalShip_PathList:
    with open(folder_path + entity) as f:
        data[0].append(entity) #Name
        line = f.readlines()
        data[0].append(line[2][12:-2]) #entityType
        if line[13][8:-1] == "FALSE": #(for special weird case)
            data[0].append(line[16][9:-1]) #credit
            data[0].append(line[17][7:-1]) #metal
            data[0].append(line[18][9:-1]) #crystal
            data[0].append(line[19][10:-1]) #slotCount
            data[0].append(line[20][10:-1]) #BuildTime
            data[0].append(line[22][12:-1]) #MaxHullPoints
            data[0].append(line[25][12:-1]) #MaxShieldPoints
            data[0].append(line[40][12:-1]) #MaxAntiMatter
            data[0].append(line[34][12:-1]) #BaseArmorPoints
            data[0].append(line[37][12:-1]) #maxMitigation
            data[0].append(line[69][11:-1]) #NumWeapons
            for weapon in range(1, int(line[69][11:-1]) + 1):
                info = weapons(69)
                for i in range(0, 7):
                    data[0].append(info[1][i])
        else: #for normal cases
            num = int(line[30][12:-1]) #soundCount1
            num = num + int(line[num + 33][12:-1]) #soundCount2
            num = num + int(line[num + 35][12:-1]) #soundCount3
            data[0].append(line[num + 39][9:-1]) #credit
            data[0].append(line[num + 40][7:-1]) #metal
            data[0].append(line[num + 41][9:-1]) #crystal
            data[0].append(line[num + 42][10:-1]) #slotCount
            data[0].append(line[num + 43][10:-1]) #BuildTime
            data[0].append(line[num + 45][12:-1]) #MaxHullPoints
            data[0].append(line[num + 48][12:-1]) #MaxShieldPoints
            data[0].append(line[num + 63][12:-1]) #MaxAntiMatter
            data[0].append(line[num + 57][12:-1]) #BaseArmorPoints
            data[0].append(line[num + 60][12:-1]) #maxMitigation
            num = num + (3*int(line[num + 75][26:-1]))
            num = num + int(line[num+82][18:-1])
            data[0].append(line[num + 88][11:-1]) #NumWeapons
            for weapon in range(1, int(line[num+88][11:-1]) + 1):
                info = weapons(num + 88)
                num = num + info[0]
                for i in range(0, 7):
                    data[0].append(info[1][i])
    csv_writer.writerows(data)
    data = [[]]

#Frigates information
for entity in Frigate_PathList:
    with open(folder_path + entity) as f:
        data[0].append(entity) #Name
        line = f.readlines()
        data[0].append(line[2][12:-2]) #entityType
        if (line[9][10:-1]) == "2":
            num = 1
        else:
            num = 0
        data[0].append(line[num + 18][9:-1]) #credit
        data[0].append(line[num + 19][7:-1]) #metal
        data[0].append(line[num + 20][9:-1]) #crystal
        data[0].append(line[num + 21][10:-1]) #slotCount
        data[0].append(line[num + 22][10:-1]) #BuildTime
        data[0].append(line[num + 25][14:-1]) #MaxHullPoints
        data[0].append(line[num + 26][16:-1]) #MaxShieldPoints
        BaseArmorPoints = (line[num + 29][16:-1]) #BaseArmorPoints
        maxMitigation = (line[num + 30][14:-1]) #maxMitigation
        if (line[num + 34][1:-1]) == "ResearchPrerequisite":
            num = num + 3
            if (line[num + 34][1:-1]) == "ResearchPrerequisite":
                num = num + 3
        NumWeapons = (line[num+44][11:-1]) #NumWeapons
        temp_data = [[],[],[],[]]
        for weapon in range(1, int(line[num+44][11:-1]) + 1):
            info = weapons(num + 44)
            num = num + info[0]
            for i in range(0, 7):
                temp_data[weapon-1].append(info[1][i])
        #num = num + int(line[num + 70][33:-5])
        #num = num + int(line[num + 74][24:-1])
        #num = num + int(line[num + 75][34:-1])
        #num = num + int(line[num + 76][24:-1])
        #num = num + int(line[num + 77][30:-1])
        MaxAntiMatter = 1 #MaxAntiMatter
       
        data[0].append(MaxAntiMatter)
        data[0].append(BaseArmorPoints)         
        data[0].append(maxMitigation)
        data[0].append(NumWeapons)
		
        for item in range(0, 4):
            for i in range(0, len(temp_data[item])):
                data[0].append(temp_data[item][i])

    csv_writer.writerows(data)
    data = [[]]

csv_file.close()
            
