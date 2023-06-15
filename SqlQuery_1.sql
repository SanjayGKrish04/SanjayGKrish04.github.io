CREATE PROCEDURE [dbo].[_FC_ImportKTICE_goalsandinterventions]
	@HHA INT,
	@USER_ID INT,
	@POC_ID INT,
	@XML_FORM_DATA XML,
	@IS_EVAL BIT,
	@DISCIPLINE INT, -- fetching from servicegroup below
	@cgtaskid int,
	@PageID	int = null,
	@CurrentPreviousState_xml xml=null,
	@echartMasterID int=null,
	@AssesssmentSummary varchar(8000)='',----pass only from oasis wizard
	@NoGoalsInterventionsRequired bit=0,
	@AuditData varchar(max)=null output,
	@AgencyLoginID varchar(100) = '',
    @superAdminLoginID varchar(100) = '',
	@AuditGuid varchar(100)='',
	@IsRefactoringEnabled BIT=0,
	@IsMasterSP BIT=0,
	@AuditHeaderData varchar(max)='',
	@AuditDBServer varchar(250)='',
	@AuditDBName varchar(50)=''
	
AS
/*

Modified 
	By: Sanjay
	On: 25th Apr 2023
	Desc: @GOAL_INTERVENTION_DATA Modified

Modified 
	By: Sanjay
	On: 17th Apr 2023
	Desc: Added @disicpline id and service category condition

Modified 
	By: Mallikarjun G B
	On: 16th September 2021
	Desc: removed set @Auditdata and implemented new audit plan

Modified 
	By: Kanchana NC
	On: 20th Oct 2020
	Desc: Added set @AuditData=null in every audit sub sp call 

Modified 
	By: Mallikarjun G B
	On: 2nd Sep 2020
	Desc: Modified set @AuditData .

	Modified 
	By: Ajay C
	On: 24th June 2020
	Desc: Dropped the temptable and added set @auditdata 
	
	Modified 
		By: Vinay Gupta
		On: 2nd June 2020
		Desc: Called the Audit data from SUB Procedure

    Modified By: Ajay C
	On         : 21th May 2020
    Desc       : Added Parameter "@AuditData" to return Audit Object record in Json Format
						(_H_ClinicalPathwaysAudit)

	Modified by :	Pavan
	Date		:	13th May, 2019
	Descrition	:	Added calling _CP_SaveEditInterventionsData,CP_SaveEditGoalsData 

	Modified by :	Pavan
	Date		:	17th April, 2019
	Descrition	:	Added Showin485

	Modified by :	Devender
	Date		:	12th feb, 2019
	Descrition	:	Added new parameter @NoGoalsInterventionsRequired

	Modified by :	Vishnu
	Date		:	8th Oct 2018
	Descrition	:	Ignored inactive carepractises in adding.
		
	Modified by :	Gurumoorthy
	Date		:	22nd Jun 2018
	Descrition	:	ClinicalPathways Audit Implementation

	Modified by :	Vishnu
	Date		:	25th July 2018
	Descrition	:	Modified goal description to 6000

    Modified by :	Abhishek
	Date		:	2nd june 2018
	Descrition	:	modified from "delete from #TempGoalsIntervention where isnull(Is_PracticeID_Avail_Online,0)=0" to "delete from #TempGoalsIntervention where isnull(Is_PracticeID_Avail_Online,0)=0 and AREA<>'Other'"

	Modified by :	Vishnu
	Date		:	1st Feb 2018
	Descrition	:	Modified avoiding connecting to clinicalpathway table inserting the req value to temp table for comparison and updation to temp table.

	Modified by :	Vishnu
	Date		:	13th Aug, 2017
	Descrition	:	Modified ignoring -8 return from  _CL_CP_SaveCarePractices for duplicare pathway id 

	Modified by :	Vishnu
	Date		:	8th Aug, 2017
	Descrition	:	Modified to to ignore performed goals which is not there. 

	Modified by :	Devender
	Date		:	5th Aug, 2017
	Descrition	:	Modified to use hha/nolock 

	Modified by :	Devender
	Date		:	1st july, 2017
	Descrition	:	Modified to read & pass the uniqueid for each care plan items to online procedure.

	Modified by :	Vishnu
	Date		:	27th Jun, 2017
	Descrition	:	(Fix issue related to invalid effective date)

	Modified by :	Devender
	Date		:	5th Jun, 2017
	Descrition	:	(Fix issue related to wrong effectectiv start dates updates)

	Modified by :	Vishnu
	Date		:	1st May 2017
	Descrition	:	ignoring the practise id's which is not available in online.

	Modified by :	Vishnu
	Date		:	24TH march 2017
	Descrition	:	GOALS DESCRIPTION SIZE INCREASED TO MAX

	Modified by :	Vishnu
	Date		:	2nd march 2017
	Descrition	:	fixed an issue releated to goals effective start date

	Modified by :	Devender
	Date		:	24th Jan, 2017
	Descrition	:	fixed an issue releated to goals data handling

	Modified
		By: Gurumoorthy
		On: 11th Jan 2017
		Desc: ClinicalPathways Soft Deletion Implementation

	Modified by :	Vishnu
	Date		:	Dec 10 2016
	Descrition	:	made changes to Time Frame

	Modified by :	Naveen
	Date		:	Nov 16 2016
	Descrition	:	To import Time Frame

	Modified by :	Vishnu
	Date		:	Nov 10 2016
	Descrition	:	made changes to @MasterRateLevel string formation change 

	Modified by: Devender
			 On: 6th sept, 2016
	Description: modified to pass missing paramter to CP_SaveGoalsAndInterventions & _CL_CP_SaveCarePractices proc

	Modified by: Mythri
			 On: Sep 1st, 2015
	Description: To exclude records where OasisDataSets.isDeleted=1 and eChartMaster.isDeleted=1

		Modified by :	Vishnu
		Date		:	May 14, 2015
		Descrition	:	Added Optional Parameter @AssesssmentSummary for saving from oasis assessments
*/
	/*
		
		-- Author:		Vishnu
		-- Create date: 19th December,2014
		-- Description:	To parse goal & Interventions xml data.

			-2=>	INTERVENTION CAN NOT BE REMOVED SINCE 485 IS LOCKED
			-3=>	INTERVENTION CAN NOT BE REMOVED SINCE IT IS ALREADY PERFORMED IN A VISIT
			-4=>	FAILED TO SAVE SINCE GOAL/INTERVENTION IS ALREADY EXISTS IN PLAN OF CARE.
			-5=>	FAILED TO SAVE GOAL & INTERVENTIONS
			-6=>	FAILED TO SAVE BASE AND MASTERY LEVEL
			-7=>	FAILED TO SAVE PREVIOUS AND CURRENT STATUS OF SHORT TERM GOALS
			
	*/
	
BEGIN
	DECLARE
	@RET_VALUE INT,
	@TRANS_COUNT INT,
	@AREA VARCHAR(100),
	@AREA_TEMP VARCHAR(100),
	@CARETYPE VARCHAR(50),
	@GOAL_INTERVENTION_DATA VARCHAR(MAX),
	@effective_start_date varchar(12),
	@nodetype varchar(1),
	@BaseRateLevel nvarchar(max),
	@MasterRateLevel nvarchar(max),
	@OtherGoalInterventions dbo.ClinicalPathwayItems,
	@planneddate varchar(12),
	@CurrentPreviousStates_String varchar(max),
	@DatasetID int=0,
	@ServicecodeID int,
	@UNIQUE_ID VARCHAR(100),
	@EpisodeID int,
	@showin485 VARCHAR(1000),
	@GOAL_GOALS_EDITDATA VARCHAR(MAX),
	@GOAL_INTERVENTION_EDITDATA VARCHAR(MAX)


		/*
		Table Variable and other variables for Audit logging Records
		*/
		Create table #ClinicalPathwayAudit194(HHA int,AuditID int,UserID int,ActivityName varchar(200),ActivityType int,UserType varchar(100),Description varchar(max),branchID int,
		IsAuditNotShow bit,AuditTime datetime,Pagecontext varchar(200),Primaryreskey varchar(50), Primaryresvalue varchar(20),POCAuditID int,cgTaskID int,ClientID int,
		ProcedureName varchar(200),UserDefined5_Name varchar(100),UserDefined5 varchar(100),UserDefined1_Name varchar(100),UserDefined1 varchar(100),Comments varchar(100),
		UserDefined2_Name varchar(100),UserDefined2 varchar(100),UserDefined3_Name varchar(100),UserDefined3 varchar(100),UserDefined4_Name varchar(100),UserDefined4 varchar(100),
		Form485ID int,IsSingleActivity bit, IsGroupActivity bit,FIRST_NAME varchar(20),LAST_NAME varchar(20),type int,ClinicalPathwayID int,EpisodeID int,SPName varchar(100),
		ModifiedContext varchar(100),EpisodeCarePlanID varchar(100),Treatment485Id int,ClientName varchar(100),Goal485Id int,ModifiedFormFriendlyID varchar(100),ClinicalPathwaysAuditID int)


		Create table #AuditTable194(Org_id int,userid int,AuditTime datetime,branchID int,EMRActiontype varchar(100), EMRActionid int,severity tinyint, restype varchar(100),
		resids varchar(max), resdata_json varchar(max),restaction int)

		Declare @BranchID int,
				@AuditTime Datetime=GetDate(),
				@IP varchar(15)='',
				@AppID int,
				@UserAgent varchar(1000)='',
				@AuditUrl varchar(500)='',
				@AuditGuid_Unique UNIQUEIDENTIFIER,
				@AuditFullDBName varchar(1000)
		 
		Select @BranchID=c.HHA_BRANCH_ID 
		                from Caregivers C with(nolock), Users U with(nolock)
							  where C.HHA=U.HHA and C.CAREGIVER_ID=U.USER_PK
							    and U.USER_ID=@USER_ID

		IF ISNULL(@IsRefactoringEnabled,0)=1
			BEGIN
			  Select @AppID=AppID,
					 @IP=IPAddress,		
					 @UserAgent=User_agent,
					 @AuditUrl =Audit_Url,
					 @AuditGuid_Unique=AuditGuid
					 from [dbo].[_UD_ReturnAuditHeaderData](@AuditHeaderData,@AuditGuid) 
			END
			
		Select @AuditFullDBName= [dbo].[_UD_GetHHABasedAuditDBInsertQuery](@AuditDBServer,@AuditDBName,@HHA)

	
	create table #temp3clinicalpathways(PATHWAY_ID int,CATEGORY char(1),AREA varchar(100),NODETYPE char(1),DESCRIPTION varchar(6000),DISCIPLINE int,FREQUENCY varchar(30),
		PRACTICE int,SERVICE_CAT TINYINT)
	
BEGIN TRY
	
	
	-- Set Initial tran count
	SET @TRANS_COUNT=@@TRANCOUNT
	IF(@TRANS_COUNT>0)
		SAVE TRANSACTION SAVE_GOAL_INTER
	ELSE
		BEGIN TRANSACTION
		
	IF(@XML_FORM_DATA IS NULL)
		RETURN 1 -- FORM IS NOT EXIST SO RETURN WITH OUT DOING ANY THING
		
	PRINT '___________________ _FC_ImportKTICE_goalsandinterventions _________________'


	select @planneddate=dbo._ud_getdate(caregivertasks.PLANNED_DATE), @ServicecodeID=caregivertasks.SERVICECODE_ID 
	from caregivertasks with(nolock) where caregivertasks.CGTASK_ID=@cgtaskid and CaregiverTasks.hha=@HHA
	
	DECLARE @servicecat_id TINYINT
	SELECT @servicecat_id=ServiceGroups.ServiceCategory, @DISCIPLINE =ServiceGroups.GroupID
				FROM ServiceGroups WITH (NOLOCK), ServiceCodes WITH (NOLOCK) 
					WHERE ServiceGroups.GroupID=ServiceCodes.GroupID
						AND ServiceCodes.SERVICE_CODE_ID=@servicecodeid
						AND ServiceCodes.HHA=@hha
						AND ServiceGroups.HHA=@hha
	
	select @DatasetID=oasisdatasets.DATASET_ID 
	from oasisdatasets with(nolock) 
	where oasisdatasets.CG_TASK_ID=@cgtaskid and oasisdatasets.hha=@hha and isnull(OasisDatasets.isDeleted,0)=0

	Select @EpisodeID = Episodes.EPISODE_ID
		from Episodes with(nolock)
		where Episodes.HHA = @HHA
				and Episodes.POC = @POC_ID

	if(isnull(@echartMasterID,0)=0)
		select @echartMasterID= eChartMasterID 
			from CaregiverTasks with(nolock) where caregivertasks.CGTASK_ID=@cgtaskid and hha=@HHA

		

	IF(EXISTS(SELECT 1 FROM @XML_FORM_DATA.nodes('CarePlan') AS TEMP(C)) or @AssesssmentSummary!='' )
			BEGIN
		create table #temp2GoalsInterventions(CAREPRACTICE_ID int,NODETYPE VARCHAR(3),AREA VARCHAR(100),DESCRIPTION VARCHAR(MAX),GOAL_BASE_LEVEL VARCHAR(MAX),GOAL_MASTERY_LEVEL VARCHAR(MAX),EFFECTIVE_START_DATE datetime,PathWayID int,FREQUENCY varchar(30), TIME_FRAME varchar(max), OFFLINE_CARE_PLAN_ID int,Showin485 varchar(1000))
	
				SELECT
					isnull(TEMP.C.value('(PRACTICE_ID)[1]', 'INT'),'') AS 'CAREPRACTICE_ID',
					isnull(TEMP.C.value('(NODE_TYPE)[1]', 'VARCHAR(3)'),'') AS 'NODETYPE',
					isnull(TEMP.C.value('(AREA)[1]', 'VARCHAR(100)'),'') AS 'AREA',
					isnull(TEMP.C.value('(DESCRIPTION)[1]', 'VARCHAR(6000)'),'') AS 'DESCRIPTION',
					isnull(TEMP.C.value('(GOAL_BASE_LEVEL)[1]', 'VARCHAR(MAX)'),'') AS 'GOAL_BASE_LEVEL',
					isnull(TEMP.C.value('(GOAL_MASTERY_LEVEL)[1]', 'VARCHAR(MAX)'),'') AS 'GOAL_MASTERY_LEVEL',
					case isnull(TEMP.C.value('(EFFECTIVE_START_DATE)[1]', 'VARCHAR(100)'),'') when '' then null else dbo._UD_GetValidDateTime(TEMP.C.value('(EFFECTIVE_START_DATE)[1]', 'VARCHAR(19)')) end   AS 'EFFECTIVE_START_DATE' ,
					'' AS 'CATEGORY',
					isnull(TEMP.C.value('(FREQUENCY)[1]', 'VARCHAR(30)'),'') AS 'FREQUENCY',
					isnull(TEMP.C.value('(TIME_FRAME)[1]', 'VARCHAR(MAX)'),'') AS 'TIME_FRAME',
					isnull(TEMP.C.value('(OFFLINE_CARE_PLAN_ID)[1]', 'INT'),'') AS 'OFFLINE_CARE_PLAN_ID',
					0 AS 'Is_PracticeID_Avail_Online',
					CASE ISNULL(TEMP.C.value('(UNIQUE_ID)[1]', 'VARCHAR(50)'),'') WHEN '' THEN NULL ELSE TEMP.C.value('(UNIQUE_ID)[1]', 'VARCHAR(100)') END AS UNIQUE_ID,
					isnull(TEMP.C.value('(Showin485)[1]',  'BIT'),0) AS 'Showin485'
					INTO #TempGoalsIntervention
				FROM 
					@XML_FORM_DATA.nodes('/CarePlan') AS TEMP(C)

				DELETE FROM #TempGoalsIntervention WHERE ISNULL(AREA,'')=''
				

			delete  #TempGoalsIntervention from CarePractices with(nolock) 
					where #TempGoalsIntervention.CAREPRACTICE_ID=CarePractices.PRACTICE_ID
					and CarePractices.[STATUS]='InActive'
					and CarePractices.HHA=@HHA


			--copying values from one temp table to another temp table for updating base and mastery level
				insert into #temp2GoalsInterventions(CAREPRACTICE_ID,NODETYPE,AREA,DESCRIPTION,GOAL_BASE_LEVEL,GOAL_MASTERY_LEVEL,EFFECTIVE_START_DATE,TIME_FRAME,OFFLINE_CARE_PLAN_ID,Showin485)
				select CAREPRACTICE_ID,NODETYPE,AREA,DESCRIPTION,GOAL_BASE_LEVEL,GOAL_MASTERY_LEVEL,EFFECTIVE_START_DATE,TIME_FRAME,OFFLINE_CARE_PLAN_ID,Showin485 
				from #TempGoalsIntervention
				

				
				UPDATE #TempGoalsIntervention
				SET	#TempGoalsIntervention.CATEGORY=CarePractices.CATEGORY,Is_PracticeID_Avail_Online=1,Showin485=isnull(CarePractices.Showin485,0)
				FROM CarePractices with(nolock)
				WHERE #TempGoalsIntervention.CAREPRACTICE_ID=CarePractices.PRACTICE_ID AND CarePractices.HHA=@HHA
			
				-----HARD CODED
				--UPDATE #TempGoalsIntervention
				--SET	#TempGoalsIntervention.CATEGORY='T' WHERE ISNULL(#TempGoalsIntervention.CATEGORY,'')=''
				
				delete from #TempGoalsIntervention where isnull(Is_PracticeID_Avail_Online,0)=0 and AREA<>'Other'
				
				SELECT DISTINCT AREA INTO #TEMP_AREA_LIST FROM #TempGoalsIntervention where AREA<>'Other'	
				
				WHILE((SELECT COUNT(*) FROM #TEMP_AREA_LIST)>0)
					BEGIN
						SET @GOAL_INTERVENTION_DATA=''
						SELECT TOP 1 @AREA=AREA FROM #TempGoalsIntervention where AREA<>'Other'
						SELECT TOP 1 @CARETYPE=CATEGORY FROM #TempGoalsIntervention WHERE AREA=@AREA
						
						SELECT  @GOAL_INTERVENTION_DATA=@GOAL_INTERVENTION_DATA+Convert(varchar,#TempGoalsIntervention.CAREPRACTICE_ID)+'£'
														+#TempGoalsIntervention.DESCRIPTION+'£'+
														#TempGoalsIntervention.NODETYPE+' '+'£'+
														#TempGoalsIntervention.FREQUENCY+'£'+
														'0'+'££'+
														isnull(#TempGoalsIntervention.UNIQUE_ID,'')+'£'
														+'¥',
								
								@effective_start_date=#TempGoalsIntervention.EFFECTIVE_START_DATE,
								@nodetype=#TempGoalsIntervention.NODETYPE
								
						FROM  #TempGoalsIntervention
						WHERE #TempGoalsIntervention.AREA=@AREA 
			
						--SET @AREA_TEMP=CASE @AREA WHEN 'Other' THEN '' ELSE @AREA END
								
						EXEC  @RET_VALUE=_CL_CP_SaveCarePracticesNew @hha=@HHA,@user=@USER_ID,@Caretype=@CARETYPE,@Area=@AREA,@PocId=@POC_ID,@Oasispoint='0',@InterventionsAndGoals=@GOAL_INTERVENTION_DATA,@isFromeval=@IS_EVAL,@discipline=@DISCIPLINE ,@pageID=null,@NodeType='',@EffectiveDate=null,@ChangeOrderID=null,@IsFromKG=1,
																@DataSet_ID=@DatasetID,@CGTaskID =@cgtaskid,@AuditGuid=@AuditGuid,@IsRefactoringEnabled=@IsRefactoringEnabled,@IsMasterSP=@IsMasterSP,@AuditHeaderData=@AuditHeaderData,@AuditDBServer=@AuditDBServer,@AuditDBName=@AuditDBName,@service_category = @servicecat_id,@ISBitFromOFFline=1
							
																
						IF(@RET_VALUE=-5 or @RET_VALUE=-8)
							SET @RET_VALUE=1 --  if -5(duplicate goals & intervnts) change to 1(no rollback)
						
						IF(@RET_VALUE=-3)
							BEGIN
								SET @RET_VALUE=-2
								IF(@TRANS_COUNT=0)
									ROLLBACK TRANSACTION
								ELSE IF(XACT_STATE() <> -1)
									ROLLBACK TRANSACTION SAVE_GOAL_INTER
								GOTO EndPoint_GOAL_INTER	
							END
						ELSE IF(@RET_VALUE=-4)
							BEGIN
								SET @RET_VALUE=-3
								IF(@TRANS_COUNT=0)
									ROLLBACK TRANSACTION
								ELSE IF(XACT_STATE() <> -1)
									ROLLBACK TRANSACTION SAVE_GOAL_INTER
								GOTO EndPoint_GOAL_INTER	
							END
					
						ELSE IF(@RET_VALUE!=1)
							BEGIN
								SET @RET_VALUE=-5
								IF(@TRANS_COUNT=0)
									ROLLBACK TRANSACTION
								ELSE IF(XACT_STATE() <> -1)
									ROLLBACK TRANSACTION SAVE_GOAL_INTER
								GOTO EndPoint_GOAL_INTER	
							END
						
						
						DELETE FROM #TempGoalsIntervention WHERE AREA=@AREA
						DELETE FROM #TEMP_AREA_LIST WHERE AREA=@AREA
					END 

	--Taking the latest values from clinicalpathway table for the poc
		insert into #temp3clinicalpathways(PATHWAY_ID,[DESCRIPTION],DISCIPLINE,NODETYPE,AREA,PRACTICE,CATEGORY,FREQUENCY,SERVICE_CAT)
		select PATHWAY_ID,[DESCRIPTION],DISCIPLINE,NODETYPE,AREA,PRACTICE,CATEGORY,FREQUENCY,service_category from ClinicalPathways with (nolock) 
				where ClinicalPathways.POC=@POC_ID and ISNULL(ClinicalPathways.isDeleted, 0) = 0 and ClinicalPathways.HHA=@HHA

		
	----updating base and mastery level, effective start date

			select @RET_VALUE=1	

			update #temp2GoalsInterventions set PathWayID=''


			--update #temp2GoalsInterventions set PathWayID=ClinicalPathways.PATHWAY_ID
			--from ClinicalPathways with(nolock)
			--	where ClinicalPathways.HHA=@hha
			--		and ClinicalPathways.DESCRIPTION=#temp2GoalsInterventions.DESCRIPTION
			--		and ClinicalPathways.DISCIPLINE=@DISCIPLINE
			--		and ClinicalPathways.AREA=#temp2GoalsInterventions.AREA
			--		and ClinicalPathways.POC=@POC_ID
			--		and ClinicalPathways.NODETYPE=#temp2GoalsInterventions.NODETYPE
			--		and #temp2GoalsInterventions.EFFECTIVE_START_DATE >= @planneddate
			--		and ISNULL(ClinicalPathways.isDeleted, 0) = 0

			update #temp2GoalsInterventions set PathWayID=#temp3clinicalpathways.PATHWAY_ID
			from #temp3clinicalpathways with(nolock)
				where  #temp3clinicalpathways.DESCRIPTION=#temp2GoalsInterventions.DESCRIPTION
					and #temp3clinicalpathways.DISCIPLINE=@DISCIPLINE
					and #temp3clinicalpathways.SERVICE_CAT = @servicecat_id
					and #temp3clinicalpathways.AREA=#temp2GoalsInterventions.AREA
					and #temp3clinicalpathways.NODETYPE=#temp2GoalsInterventions.NODETYPE
					and #temp2GoalsInterventions.EFFECTIVE_START_DATE >= @planneddate
		

			--update #temp2GoalsInterventions set PathWayID=ClinicalPathways.PATHWAY_ID
			--from ClinicalPathways  with(nolock)
			--	where ClinicalPathways.HHA=@hha
			--		and ClinicalPathways.DESCRIPTION=#temp2GoalsInterventions.DESCRIPTION
			--		and ClinicalPathways.DISCIPLINE=@DISCIPLINE
			--		and ClinicalPathways.AREA=#temp2GoalsInterventions.AREA
			--		and ClinicalPathways.POC=@POC_ID
			--		and ClinicalPathways.NODETYPE=#temp2GoalsInterventions.NODETYPE
			--		and isnull(#temp2GoalsInterventions.PathWayID,0)=0
			--		and ISNULL(ClinicalPathways.isDeleted, 0) = 0
			update #temp2GoalsInterventions set PathWayID=#temp3clinicalpathways.PATHWAY_ID
			from #temp3clinicalpathways  with(nolock)
				where  #temp3clinicalpathways.DESCRIPTION=#temp2GoalsInterventions.DESCRIPTION
					and #temp3clinicalpathways.DISCIPLINE=@DISCIPLINE
					and #temp3clinicalpathways.SERVICE_CAT = @servicecat_id
					and #temp3clinicalpathways.AREA=#temp2GoalsInterventions.AREA
					and #temp3clinicalpathways.NODETYPE=#temp2GoalsInterventions.NODETYPE
					and isnull(#temp2GoalsInterventions.PathWayID,0)=0
			

			IF(isnull(@RET_VALUE,0)=1)
				 begin
					--insert into _H_ClinicalPathwaysAudit (CreatedBy, HHA, ActivityName, ActivityType, ClinicalPathwayID, 
					--ClientID, EpisodeID, CGTaskID,Description, SPName, ModifiedContext, EpisodeCarePlanID)

					insert into #ClinicalPathwayAudit194(UserID,HHA,ActivityName,ActivityType,ClinicalPathwayID,
					ClientID,EpisodeID,cgTaskID,Description,SPName,ModifiedContext,EpisodeCarePlanID)


						select @USER_ID, @HHA, 'CP_CL_EditCarePlan', 3102, ClinicalPathways.PATHWAY_ID, ClinicalPathways.ClientID, @EpisodeID, @cgtaskid,
								IIF(ClinicalPathways.NODETYPE = 'I', 'Intervention', 'Goal') + ' Modified during Import: ' +
								'Planned Date changed from ''' + ISNULL(CONVERT(varchar, ClinicalPathways.PlannedDate, 101), '') + ''' to ''' + ISNULL(CONVERT(varchar, #temp2GoalsInterventions.EFFECTIVE_START_DATE, 101), ''),
								'_FC_ImportKTICE_goalsandinterventions', 'Import', ClinicalPathways.EpisodeCarePlanID
							from #temp2GoalsInterventions, ClinicalPathways with(nolock)
							where ClinicalPathways.PATHWAY_ID = #temp2GoalsInterventions.PathWayID
								and ClinicalPathways.HHA = @hha
								and ClinicalPathways.DISCIPLINE = @DISCIPLINE
								and ClinicalPathways.AREA = #temp2GoalsInterventions.AREA
								and ClinicalPathways.POC = @POC_ID
								and ClinicalPathways.NODETYPE = #temp2GoalsInterventions.NODETYPE
								and isnull(#temp2GoalsInterventions.PathWayID, 0) > 0
								and ISNULL(ClinicalPathways.isDeleted, 0) = 0
								and ISNULL(CONVERT(varchar, ClinicalPathways.PlannedDate, 101), '') != ISNULL(CONVERT(varchar, #temp2GoalsInterventions.EFFECTIVE_START_DATE, 101), '')

					update ClinicalPathways set PlannedDate = #temp2GoalsInterventions.EFFECTIVE_START_DATE
							from #temp2GoalsInterventions where ClinicalPathways.HHA=@hha
											--and ClinicalPathways.DESCRIPTION=#temp2GoalsInterventions.DESCRIPTION
											and ClinicalPathways.PATHWAY_ID=#temp2GoalsInterventions.PathWayID
											and ClinicalPathways.DISCIPLINE=@DISCIPLINE
											and ClinicalPathways.AREA=#temp2GoalsInterventions.AREA
											and ClinicalPathways.POC=@POC_ID
											and ClinicalPathways.NODETYPE=#temp2GoalsInterventions.NODETYPE
											and isnull(#temp2GoalsInterventions.PathWayID,0)>0
											and ISNULL(ClinicalPathways.isDeleted, 0) = 0

					UPDATE #temp2GoalsInterventions
						SET	 Showin485=isnull(CarePractices.Showin485,0)
						FROM CarePractices with(nolock)
						WHERE #temp2GoalsInterventions.CAREPRACTICE_ID=CarePractices.PRACTICE_ID AND CarePractices.HHA=@HHA	
			 
				 end
				
				
				insert into _H_ClinicalPathwaysAudit (CreatedBy, HHA, ActivityName, ActivityType, ClinicalPathwayID, 
					ClientID, EpisodeID, CGTaskID,Description, SPName, ModifiedContext, EpisodeCarePlanID,IsMovetoHDFS,AgencyLoginID ,SuperAdminLoginID)

				select UserID,HHA,ActivityName,ActivityType,ClinicalPathwayID,
					ClientID,EpisodeID,cgTaskID,Description,SPName,ModifiedContext,EpisodeCarePlanID,1,@AgencyLoginID,@superAdminLoginID 
				from #ClinicalPathwayAudit194

							Insert into #AuditTable194(Org_id ,userid ,AuditTime ,branchID ,EMRActiontype , EMRActionid,severity,restype , resids,resdata_json,restaction)
				                 select HHA,@USER_ID,@AuditTime,@BranchID,'Modified Care Plan',132,1,'Care Plan',

								 replace('ParentKey=CarePlan' 
								+'/'+'UserType='+Convert(varchar,ISNULl('Caregiver','')) 
								+'/'+'ClinicalPathWayID='+Convert(varchar,ISNULl(ClinicalPathwayID,'')) 
								+'/'+'ClientName='+convert(varchar,ISNULL(ClientName,'')) 
								+'/ClientID='+ +convert(varchar,ISNULL(ClientID,'')) 
								+'/AgencyLoginID='+ +convert(varchar,ISNULL(@AgencyLoginID,''))+
								+'/superAdminLoginID='+ +convert(varchar,ISNULL(@superAdminLoginID,''))+
								+'/IsAuditNotShow='+convert(varchar,0),char(9),'') as res_ids,

								replace(('{"Audittext":"' + dbo.[_UD_EncodeSpecialCharacter](Description)
								+'", "Page":"' --+ Replace(ISNULL(PageID,''),'"','/') 
								+'", "SQLAuditID":' + Replace(ISNULL(ClinicalPathwaysAuditID,''),'"','/')
								+', "EpisodeID":"' + Replace(ISNULL(EpisodeID,''),'"','/')
								+'", "IsSingleActivity":"' + Replace(ISNULL('',''),'"','/')
								+'", "IsGroupActivity":"' + Replace(ISNULL('',''),'"','/')
								+'", "Treatment485ID":"' + Replace(ISNULL(Treatment485Id,''),'"','/')
								+'", "Goal485ID":"' + Replace(ISNULL(Goal485Id,''),'"','/')
								+'", "Form485ID":"' + Replace(ISNULL(Form485ID,''),'"','/')
								+'", "CgTaskID":"' + Replace(ISNULL(cgTaskID,''),'"','/')
								+'", "ModifiedFormFriendlyID":"' + Replace(ISNULL(ModifiedFormFriendlyID,''),'"','/')
								+'", "UserKeyType1":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyType2":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyType3":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyType4":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyType5":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyValue1":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyValue2":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyValue3":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyValue4":"' + Replace(ISNULL('',''),'"','/')
								+'", "UserKeyValue5":"' + Replace(ISNULL('',''),'"','/')
								+'", "ParentActivityName":"' + Replace(REplace(ISNULL(ActivityName,''),' ',''),'"','/')
								+'", "ProcedureName":"' + Replace(ISNULL(SPName,''),'"','/')
								+ '"}'),char(9),'') as resdata_json,2
				from #ClinicalPathwayAudit194

		
			  if ISNULL(@IsRefactoringEnabled,0)=1
						Begin
						EXEC('insert into '+ @AuditFullDBName +' (Org_id ,userid , AuditTime ,branchID,severity ,EMRActiontype ,EMRActionid,restype,restaction,resids,resdata_json,AuditGuid,Audit_url,User_Agent,ipAddress,appid)
							  Select Org_id ,userid , Convert(varchar,AuditTime,25) ,branchID,severity ,EMRActiontype ,EMRActionid,restype,restaction,resids,resdata_json,'''+@AuditGuid_Unique+''','''+@AuditUrl+''','''+@UserAgent+''','''+@IP+''','+@AppID+' from #AuditTable194')
						END
					 
					 
				-------------------------------------------------------------
				set @GOAL_GOALS_EDITDATA=''
				set @GOAL_INTERVENTION_EDITDATA=''
				IF(isnull(@RET_VALUE,0)=1)
					begin
						SELECT   @GOAL_GOALS_EDITDATA=@GOAL_GOALS_EDITDATA+Convert(varchar,isnull(#temp2GoalsInterventions.PathWayID,0))+'¥'
									+#temp2GoalsInterventions.[DESCRIPTION]+'¥¥¥'+
									Convert(varchar,FORMAT (isnull( #temp2GoalsInterventions.EFFECTIVE_START_DATE,''), 'd', 'en-us'))+'¥'+
									''+'¥'+	
									Convert(varchar,#temp2GoalsInterventions.Showin485)+'¥'+
									+'0'+'¥'+
									 '0'+'¥'+
									 +'0'+'¥'+
									 '0'+'¥'+
									+''+'¥ô'
									
						FROM  #temp2GoalsInterventions WHERE #temp2GoalsInterventions.AREA=@AREA AND #temp2GoalsInterventions.NODETYPE='G'
					AND isnull(#temp2GoalsInterventions.PathWayID,0)>0	

				if(isnull(@GOAL_GOALS_EDITDATA,'')!='')
					begin
						EXEC  @RET_VALUE=CP_SaveEditGoalsData @hha=@HHA,@UserID=@USER_ID,@PocId=@POC_ID,
															@SaveGoalsData=@GOAL_GOALS_EDITDATA,@isDiscontinue=0,
															@DiscontinuedDat='',@pageID=0,@DataSetID=0,@CGTaskID=@cgtaskid,
															@NodeType='G',@ChangeOrderID=0,@Context='',@AuditGuid=@AuditGuid,
															@IsRefactoringEnabled=@IsRefactoringEnabled,@IsMasterSP=@IsMasterSP,
															@AuditHeaderData=@AuditHeaderData,@AuditDBServer=@AuditDBServer,
															@AuditDBName=@AuditDBName
							
					end				
						SELECT   @GOAL_INTERVENTION_EDITDATA=@GOAL_INTERVENTION_EDITDATA+Convert(varchar,isnull(#temp2GoalsInterventions.PathWayID,0))+'¥'
									+#temp2GoalsInterventions.[DESCRIPTION]+'¥'+
									Convert(varchar,FORMAT (isnull( #temp2GoalsInterventions.EFFECTIVE_START_DATE,''), 'd', 'en-us'))+'¥'+
									''+'¥'+	--Convert(varchar,FORMAT (isnull(#temp2GoalsInterventions.DISCOUNTINUED_DATE,''), 'd', 'en-us'))+'¥'+							
									Convert(varchar,#temp2GoalsInterventions.Showin485)+'¥'+
									+'0'+'¥'+
									 '0'+'¥'+
									 +'0'+'¥'+
									 '0'+'¥'+
									+''+'¥ô'   							
						FROM  #temp2GoalsInterventions
						WHERE #temp2GoalsInterventions.AREA=@AREA AND #temp2GoalsInterventions.NODETYPE='I'
						AND isnull(#temp2GoalsInterventions.PathWayID,0)>0

				if(isnull(@GOAL_INTERVENTION_EDITDATA,'')!='')
					begin
						EXEC _CP_SaveEditInterventionsData @HHA=@HHA,@UserID=@USER_ID,@POCID=@POC_ID,
															@SaveInterventionsData=@GOAL_INTERVENTION_EDITDATA,
															@isDiscontinue=0,@DiscontinuedDat='',@pageID=0,@DataSetID=0,@CGTaskID=@cgtaskid,
															@NodeType='I',@ChangeOrderID=0,@Context='',@AuditGuid=@AuditGuid,@IsRefactoringEnabled=@IsRefactoringEnabled,
															@IsMasterSP=@IsMasterSP,@AuditHeaderData=@AuditHeaderData,@AuditDBServer=@AuditDBServer,@AuditDBName=@AuditDBName
							
					end
				end
				-------------------------------------------------------------

				-- Save Other goals & Interventions
				IF EXISTS(SELECT 1 FROM #TempGoalsIntervention WHERE AREA='Other')
					BEGIN
						
						INSERT INTO @OtherGoalInterventions(PATHAWAYID,DESCRIPTION,Area,NodeType)
						SELECT 0, ISNULL(DESCRIPTION,''),'Other',NODETYPE FROM #TempGoalsIntervention WHERE AREA='Other'

						
						--UPDATE @OtherGoalInterventions SET PATHAWAYID=ClinicalPathways.PATHWAY_ID
					 --   FROM ClinicalPathways with(nolock)
						--WHERE ClinicalPathways.POC=@POC_ID AND [ClinicalPathways].[NodeType]='G' AND DISCIPLINE=@DISCIPLINE 
					 --   AND ClinicalPathways.AREA='Other' AND [@OtherGoalInterventions].[NodeType]='G' 
						--AND ClinicalPathways.HHA=@HHA and ISNULL(ClinicalPathways.isDeleted, 0) = 0

						UPDATE @OtherGoalInterventions SET PATHAWAYID=#temp3clinicalpathways.PATHWAY_ID
					    FROM #temp3clinicalpathways with(nolock)
						WHERE  [#temp3clinicalpathways].[NodeType]='G' 
						AND DISCIPLINE=@DISCIPLINE 
						AND #temp3clinicalpathways.SERVICE_CAT = @servicecat_id
					    AND #temp3clinicalpathways.AREA='Other' 
						AND [@OtherGoalInterventions].[NodeType]='G' 
						 

					 --   UPDATE @OtherGoalInterventions SET PATHAWAYID=ClinicalPathways.PATHWAY_ID
					 --   FROM ClinicalPathways with(nolock)
						--WHERE ClinicalPathways.POC=@POC_ID AND [ClinicalPathways].[NodeType]='I' AND DISCIPLINE=@DISCIPLINE 
					 --   AND ClinicalPathways.AREA='Other' AND [@OtherGoalInterventions].[NodeType]='I' 
						--AND ClinicalPathways.HHA=@HHA and ISNULL(ClinicalPathways.isDeleted, 0) = 0

						UPDATE @OtherGoalInterventions SET PATHAWAYID=#temp3clinicalpathways.PATHWAY_ID
					    FROM #temp3clinicalpathways with(nolock)
						WHERE [#temp3clinicalpathways].[NodeType]='I' AND DISCIPLINE=@DISCIPLINE 
						and #temp3clinicalpathways.SERVICE_CAT = @servicecat_id
					    AND #temp3clinicalpathways.AREA='Other' AND [@OtherGoalInterventions].[NodeType]='I' 
					

					
					END
								
					set @BaseRateLevel=(select convert(varchar,#temp2GoalsInterventions.PathWayID)+'§'+#temp2GoalsInterventions.GOAL_BASE_LEVEL+'s' from #temp2GoalsInterventions for xml path (''))
					set @MasterRateLevel=(select convert(varchar,#temp2GoalsInterventions.PathWayID)+'§'+#temp2GoalsInterventions.GOAL_MASTERY_LEVEL+'s' from #temp2GoalsInterventions for xml path (''))		
					select @MasterRateLevel = @MasterRateLevel +'±'+ (select convert(varchar,#temp2GoalsInterventions.PathWayID)+'§'+isnull(rtrim(ltrim(#temp2GoalsInterventions.TIME_FRAME)),'')+N'ô' from #temp2GoalsInterventions for xml path (''))
					set @showin485=(select convert(varchar,#temp2GoalsInterventions.PathWayID)+'¥'+#temp2GoalsInterventions.Showin485+N'¥ô' from #temp2GoalsInterventions for xml path (''))
 
						EXEC @RET_VALUE = CP_SaveGoalsAndInterventions @HHAID=@HHA,@USERID=@USER_ID,@POCID=@POC_ID,@ClinicalPathways=@OtherGoalInterventions,@DELETEDITEMS='',@DatasetID=@DatasetID,@AssesssmentSummary=@AssesssmentSummary,@showIn485=@showin485,@isFromeval=0,@discipline=@DISCIPLINE,@NoLongerPathwayIDs='',@BaseRateLevel=@BaseRateLevel,@MasterRateLevel=@MasterRateLevel,@PrintAssessmentSummaryinPOC=0,
																		@eChartMasterID=@eChartMasterID,@AuditGuid=@AuditGuid,@IsRefactoringEnabled=@IsRefactoringEnabled,@IsMasterSP=@IsMasterSP,@AuditHeaderData=@AuditHeaderData,@AuditDBServer=@AuditDBServer,@AuditDBName=@AuditDBName
	
						IF(@RET_VALUE<>1)
							BEGIN
								SET @RET_VALUE=-6
								IF(@TRANS_COUNT=0)
									ROLLBACK TRANSACTION
								ELSE IF(XACT_STATE() <> -1)
									ROLLBACK TRANSACTION SAVE_GOAL_INTER
								GOTO EndPoint_GOAL_INTER	
							END


					  if(isnull(@eChartMasterID,0)>0)
						begin
							Update eChartMaster
								set NoGoalsInterventionsRequired = ISNULL(@NoGoalsInterventionsRequired, 0)
									where eChartMaster.HHA = @HHA and eChartMaster.eChartMasterID = @eChartMasterID
						end
			END

			--clearing the old values for clinicalpathways
			delete from #temp3clinicalpathways

			--Taking the latest values from clinicalpathway table for the poc
			insert into #temp3clinicalpathways(PATHWAY_ID,[DESCRIPTION],DISCIPLINE,NODETYPE,AREA,PRACTICE,CATEGORY,FREQUENCY,SERVICE_CAT)
			select PATHWAY_ID,[DESCRIPTION],DISCIPLINE,NODETYPE,AREA,PRACTICE,CATEGORY,FREQUENCY,service_category from ClinicalPathways with (nolock) 
				where ClinicalPathways.POC=@POC_ID and ISNULL(ClinicalPathways.isDeleted, 0) = 0 and ClinicalPathways.HHA=@HHA

	-----current and previous status goals
	if(EXISTS(SELECT 1 FROM @CurrentPreviousState_xml.nodes('ShortTermGoalItem') AS TEMP(C)))
		begin
		
		create table #tempPreviousCurrentStates(PATHWAY_ID int,PREVIOUS_STATUS VARCHAR(1000),CURRENT_STATUS VARCHAR(1000),IS_MET bit,PRACTICE_ID int,IS_ADHOC bit,Progress_ID int,AREA varchar(100))
				insert into #tempPreviousCurrentStates(PATHWAY_ID,PREVIOUS_STATUS,CURRENT_STATUS,IS_MET,PRACTICE_ID,IS_ADHOC,Progress_ID,AREA)
				SELECT 
					isnull(TEMP.C.value('(PATHWAY_ID)[1]', 'INT'),0),
					isnull(TEMP.C.value('(PREVIOUS_STATUS)[1]', 'VARCHAR(1000)'),''),
					isnull(TEMP.C.value('(CURRENT_STATUS)[1]', 'VARCHAR(1000)'),''),
					isnull(TEMP.C.value('(IS_MET)[1]', 'bit'),''),
					isnull(TEMP.C.value('(PRACTICE_ID)[1]', 'int'),0),
					TEMP.C.value('(IS_ADHOC)[1]', 'bit'),
					0,
					''
				FROM 
					@CurrentPreviousState_xml.nodes('/ShortTermGoalItem') AS TEMP(C)
		
		
		--update #tempPreviousCurrentStates set PATHWAY_ID=ClinicalPathways.PATHWAY_ID
		--	from ClinicalPathways with(nolock)
		--		where ClinicalPathways.HHA=@hha
		--			and ClinicalPathways.PRACTICE=#tempPreviousCurrentStates.PRACTICE_ID
		--			and ClinicalPathways.DISCIPLINE=@DISCIPLINE
		--			and ClinicalPathways.POC=@POC_ID
		--			and isnull(#tempPreviousCurrentStates.PATHWAY_ID,0)=0
		--			and ISNULL(ClinicalPathways.isDeleted, 0) = 0
		
	
		--update #tempPreviousCurrentStates set PATHWAY_ID=ClinicalPathways.PATHWAY_ID 
		--	from ClinicalPathways with(nolock)
		--		where isnull(ClinicalPathways.PRACTICE,0)=0 
		--		and ClinicalPathways.DISCIPLINE=@DISCIPLINE 
		--		and ClinicalPathways.POC=@POC_ID 
		--		and ClinicalPathways.NODETYPE='G' 
		--		and ClinicalPathways.HHA=@HHA
		--		and isnull(#tempPreviousCurrentStates.PATHWAY_ID,0)=0
		--		and ISNULL(ClinicalPathways.isDeleted, 0) = 0
		update #tempPreviousCurrentStates set PATHWAY_ID=#temp3clinicalpathways.PATHWAY_ID
			from #temp3clinicalpathways with(nolock)
				where  #temp3clinicalpathways.PRACTICE=#tempPreviousCurrentStates.PRACTICE_ID
					and #temp3clinicalpathways.DISCIPLINE=@DISCIPLINE
					and #temp3clinicalpathways.SERVICE_CAT=@servicecat_id
					and isnull(#tempPreviousCurrentStates.PATHWAY_ID,0)=0
					
		
	
		update #tempPreviousCurrentStates set PATHWAY_ID=#temp3clinicalpathways.PATHWAY_ID 
			from #temp3clinicalpathways with(nolock)
				where isnull(#temp3clinicalpathways.PRACTICE,0)=0 
				and #temp3clinicalpathways.DISCIPLINE=@DISCIPLINE
				and #temp3clinicalpathways.SERVICE_CAT=@servicecat_id
				and #temp3clinicalpathways.NODETYPE='G'
				and isnull(#tempPreviousCurrentStates.PATHWAY_ID,0)=0
		
		-- delete unnecessary records comming from xml
		delete from  #tempPreviousCurrentStates 
				where isnull(PATHWAY_ID ,0)=0 --and isnull(PRACTICE_ID,0)=0 
			--		and isnull(PREVIOUS_STATUS,'')='' and isnull(CURRENT_STATUS,'')= '' and isnull(IS_MET,0)=0
					
		--if exists(select * from #tempPreviousCurrentStates )
		--begin
		--	if not exists(select * from #tempPreviousCurrentStates,ClinicalPathways with(nolock)
		--		where #tempPreviousCurrentStates.PATHWAY_ID=ClinicalPathways.PATHWAY_ID and ClinicalPathways.hha=@HHA and ClinicalPathways.POC=@POC_ID and ISNULL(ClinicalPathways.isDeleted, 0) = 0)
		--			begin
		--				set @RET_VALUE=-10
		--				GOTO EndPoint_GOAL_INTER
		--			end
		--end

		if exists(select * from #tempPreviousCurrentStates )
		begin
			if not exists(select * from #tempPreviousCurrentStates,#temp3clinicalpathways with(nolock)
				where #tempPreviousCurrentStates.PATHWAY_ID=#temp3clinicalpathways.PATHWAY_ID )
					begin
						set @RET_VALUE=-10
						GOTO EndPoint_GOAL_INTER
					end
		end


		--update #tempPreviousCurrentStates set AREA=ClinicalPathways.AREA
		--	from ClinicalPathways with(nolock)
		--		where ClinicalPathways.PATHWAY_ID=#tempPreviousCurrentStates.PATHWAY_ID
		--			and ClinicalPathways.HHA=@HHA
		--			and ClinicalPathways.POC=@POC_ID
		--			and ClinicalPathways.DISCIPLINE=@DISCIPLINE
		--			and ISNULL(ClinicalPathways.isDeleted, 0) = 0
		update #tempPreviousCurrentStates set AREA=#temp3clinicalpathways.AREA
			from #temp3clinicalpathways with(nolock)
				where #temp3clinicalpathways.PATHWAY_ID=#tempPreviousCurrentStates.PATHWAY_ID
					and #temp3clinicalpathways.DISCIPLINE=@DISCIPLINE
					and #temp3clinicalpathways.SERVICE_CAT=@servicecat_id

		update #tempPreviousCurrentStates set Progress_ID=goalsprogress.GoalProgressID
			from goalsprogress with(nolock)
				where goalsprogress.GoalMasterID=#tempPreviousCurrentStates.PATHWAY_ID
					and GoalsProgress.HHA=@HHA
					and  GoalsProgress.FormID=@echartMasterID

				set @CurrentPreviousStates_String=(select convert(varchar,#tempPreviousCurrentStates.Progress_ID)+'±'+convert(varchar,#tempPreviousCurrentStates.PATHWAY_ID)+'±'+#tempPreviousCurrentStates.PREVIOUS_STATUS+'±'+#tempPreviousCurrentStates.CURRENT_STATUS+'±'+#tempPreviousCurrentStates.AREA+'ôôô' from #tempPreviousCurrentStates for xml path(''))
			
			EXEC @RET_VALUE = CP_SaveCurrentPreviousStatusofGoals @hha=@HHA,@user=@USER_ID,@pageID=@PageID,@CurentPreviousStatusData=@CurrentPreviousStates_String,@eChartMasterID=@echartMasterID,@CGTaskID=@cgtaskid,
										@AuditGuid=@AuditGuid,@IsRefactoringEnabled=@IsRefactoringEnabled,@IsMasterSP=@IsMasterSP,@AuditHeaderData=@AuditHeaderData,@AuditDBServer=@AuditDBServer,@AuditDBName=@AuditDBName
			
						
						IF(@RET_VALUE<>1)
							BEGIN
								SET @RET_VALUE=-7
								IF(@TRANS_COUNT=0)
									ROLLBACK TRANSACTION
								ELSE IF(XACT_STATE() <> -1)
									ROLLBACK TRANSACTION SAVE_GOAL_INTER
								GOTO EndPoint_GOAL_INTER	
							END

		END
    ------
	IF(@TRANS_COUNT=0)
					
		COMMIT TRANSACTION
		
END TRY	
BEGIN CATCH
	SET @RET_VALUE=0
	SELECT ERROR_LINE(),ERROR_MESSAGE();
	
	IF(@TRANS_COUNT=0)
		ROLLBACK TRANSACTION
	ELSE IF(XACT_STATE() = -1)
		ROLLBACK TRANSACTION
		
	exec _Utils_WriteProcedureException @HHA, @USER_ID	
	GOTO EndPoint_GOAL_INTER
END CATCH
	
SET @RET_VALUE=1

EndPoint_GOAL_INTER:

IF OBJECT_ID('#TempGoalsIntervention') IS NOT NULL
	DROP TABLE #TempGoalsIntervention
	
IF OBJECT_ID('#TEMP_AREA_LIST') IS NOT NULL
	DROP TABLE #TEMP_AREA_LIST

IF OBJECT_ID('#temp2GoalsInterventions') IS NOT NULL
	DROP TABLE #temp2GoalsInterventions

IF OBJECT_ID('#tempPreviousCurrentStates') IS NOT NULL
	DROP TABLE #tempPreviousCurrentStates

IF OBJECT_ID('##temp3clinicalpathways') IS NOT NULL
	DROP TABLE #temp3clinicalpathways

PRINT 'RETURN _FC_ImportKTICE_goalsandinterventions: '+ STR(@RET_VALUE)
PRINT '___________________ Ending _FC_ImportKTICE_goalsandinterventions _________________'



if OBJECT_ID('#ClinicalPathwayAudit194') is not null
drop table #ClinicalPathwayAudit194
if OBJECT_ID('#AuditTable194') is not null
drop table #AuditTable194

RETURN @RET_VALUE

END
