/* Extract all user/group/role metadata - requires administrator user */
%mduextr(libref=work);

/*The following code stages group and role relationships, and joins additional details:*/
proc sql;
	create table gginfo as
		select
			groupmemgroups_info.memId as object_id,
			groupmemgroups_info.memName as object_name,
			object.displayname as object_displayname,
			coalesceC(upcase(object.grpType),'GROUP') length=20 as object_type,
			object.description as object_description,
			groupmemgroups_info.id as parent_id,
			groupmemgroups_info.Name as parent_name,
			parent.displayname as parent_displayname,
			coalesceC(upcase(parent.grpType),'GROUP') length=20 as parent_type,
			parent.description as parent_description
		from groupmemgroups_info
			left join idgrps as parent on groupmemgroups_info.id = parent.keyid
			left join idgrps as object on groupmemgroups_info.memid = object.keyid
	;
quit;

/*The following code stages user memberships for groups and roles, and also joins in additional details:*/

proc sql;
	create table gpinfo as
		select
			groupmempersons_info.memId as object_id,
			groupmempersons_info.memName as object_name,
			usr.displayname as object_displayname,
			'USER' length=20 as object_type,
			groupmempersons_info.memDesc as object_description,
			usr.title as user_title,
			groupmempersons_info.id as parent_id,
			groupmempersons_info.name as parent_name,
			group.displayname as parent_displayname,
			coalesceC(upcase(group.grpType),'GROUP') length=20 as parent_type,
			group.description as parent_description
		from groupmempersons_info
			left join idgrps as group on groupmempersons_info.id = group.objid
			left join person as usr on groupmempersons_info.memid = usr.objid
	;
quit;

/*
	After user, group, and role memberships are extracted they are appended together along with the IDGRPS source table. 
	The IDGRPS table contains a record for every group and role. 
	Appending the IDGRPS table ensures groups and roles can terminate properly in an ungrouped network type.
	The following code appends necessary data staged previously, cleans up variables, and defines a relationship type variable:
*/
data metadata_user_object_rels;
	length
		object_id $20 object_name $100 object_displayname $256
		object_type $100 object_description $256 user_title $200
		parent_id $20 parent_name $100 parent_displayname $256
		parent_type $100 parent_description $256 relationship_type $20
	;
	set
		gpinfo(in=users)
		gginfo(in=groups)
		idgrps(in=terminating_groups drop=externalkey keyid
		rename=
		(
		objid = object_id
		name = object_name
		displayname = object_displayname
		grpType = object_type
		description = object_description
			)
			);

	/* Cleanup */
	object_displayname = coalesceC(object_displayname,object_name);
	parent_displayname = coalesceC(parent_displayname,parent_name);

	if terminating_groups then
		object_type = coalesceC(upcase(object_type),'GROUP');

	/* Define relationships */
	if users then
		relationship_type = 'GROUP-USER';
	else if groups then
		relationship_type = CATS(upcase(parent_type),'-',upcase(object_type));
	else if terminating_groups then
		relationship_type = 'TERMINATING';
run;

/*
The final data set contains the following columns:
- object_id – Unique ID from SAS metadata for user, group, or role.
- object_name – Name of object (user ID, group name, or role name).
- object_displayname – Display name of user, group, or role.
- object_type – Type of object (values equal USER, GROUP, or ROLE).
- object_description – Description provided from SAS metadata.
- user_title – User title if the object is a user.
- parent_id – Unique ID of the parent object, either a group or role.
- parent_name – Name of parent object (if exists).
- parent_displayname – Display name of parent object (if exists).
- parent_type – Type of parent object (values equal USER, GROUP, or ROLE).
- parent_description – Description provided from SAS metadata for parent object.
- relationship_type – Describes relationship between object and parent (ex: USER-GROUP)
- relationship_count – Indicator to count relationships.
*/