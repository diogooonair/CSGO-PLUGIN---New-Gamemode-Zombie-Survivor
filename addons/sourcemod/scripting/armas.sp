#include <sourcemod>
#include <smlib>

public Plugin:myinfo = 
{
    name = "Remove Weapons",
    author = "Marcus",
    description = "Removes a players' weaopon(s) on spawn and gives anothers",
    version = "0.0.2",
    url = "http://www.sourcemod.net"
};

public OnPluginStart()
{
    HookEvent("player_spawn", Event_Spawn);
    HookEvent("round_start", Event_Start);
}

public Action:Event_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new i = GetClientOfUserId(GetEventInt(event, "userid"));
    RemoveWeapons(i)

}

public Action:Event_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
    new i = GetClientOfUserId(GetEventInt(event, "userid"));
    RemoveWeapons(i)
}

RemoveWeapons(client)
{
    new team = GetClientTeam(client);
    
    Client_RemoveAllWeapons(client, "", true); // Removes all the weapons ; Add a weapon name into the "" to exclude that weapon.
    if( team != 1 && team == 2 ) // Checks if the player is not a spectator and if the player is on Red Team
    {
        Client_GiveWeaponAndAmmo(client, "weapon_taser", true, 90); // Change weapon_glock to the weapon you want. 90 is the amount of ammo given.
        Client_GiveWeaponAndAmmo(client, "weapon_knife", true, 90); // Change weapon_ak47 to the weapon you want.
    } else if ( team != 1 && team == 3) // Checks if the player is not a spectator and if the player is on the Blu Team
    {
        Client_GiveWeaponAndAmmo(client, "weapon_knife", true, 90); // Change weapon_p228 to the weapon you want. 90 is the amount of ammo given.
        Client_GiveWeaponAndAmmo(client, "weapon_deagle", true, 90); // Change weapon_m4a1 to the weapon you want.
    }
    
}  