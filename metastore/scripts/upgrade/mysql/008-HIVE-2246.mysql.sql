DELIMITER $$
DROP PROCEDURE IF EXISTS REVERT $$
DROP PROCEDURE IF EXISTS ALTER_SDS $$
DROP PROCEDURE IF EXISTS CREATE_SDS $$
DROP PROCEDURE IF EXISTS CREATE_TABLES $$
DROP PROCEDURE IF EXISTS MIGRATE_TABLES $$
DROP PROCEDURE IF EXISTS MIGRATE_PARTITIONS $$
DROP PROCEDURE IF EXISTS MIGRATE $$
DROP PROCEDURE IF EXISTS PRE_MIGRATE $$
DROP PROCEDURE IF EXISTS RENAME_TMP_COLUMNS $$
DROP PROCEDURE IF EXISTS CREATE_TABLE_SDS $$

/* Call this procedure to revert all changes by this script */
CREATE PROCEDURE REVERT()
  BEGIN
    ALTER TABLE SDS
      DROP FOREIGN KEY `SDS_FK2`
    ;
    ALTER TABLE SDS
      DROP COLUMN CD_ID
    ; 
    DROP TABLE IF EXISTS COLUMNS_V2;
    DROP TABLE IF EXISTS TABLE_SDS;
    DROP TABLE IF EXISTS CDS;

  END $$

/* Alter the SDS table to:
 *  - add the column CD_ID
 *  - add a foreign key on CD_ID
 *  - create an index on CD_ID
 */ 
CREATE PROCEDURE ALTER_SDS()
  BEGIN
    ALTER TABLE SDS
      ADD COLUMN CD_ID bigint(20) NULL
      AFTER SD_ID
    ;
    SELECT 'Added the column CD_ID to SD_ID';
    ALTER TABLE SDS
      ADD CONSTRAINT `SDS_FK2`
      FOREIGN KEY (`CD_ID`) REFERENCES `CDS` (`CD_ID`)
    ;
    SELECT 'Created a FK Constraint on CD_ID in SDS';
    CREATE INDEX `SDS_N50` ON SDS 
      (CD_ID)
    ;
    SELECT 'Added an index on CD_ID in SDS';
  END $$

/*
 * Creates the following tables:
 *  - CDS
 *  - COLUMNS_V2
 * The new columns table is called COLUMNS_V2
 * because many columns are removed, and the schema is changed.
 * It'd take too long to migrate and keep the same table.
 */
CREATE PROCEDURE CREATE_TABLES()
  BEGIN
    CREATE TABLE IF NOT EXISTS `CDS` (
      `CD_ID` bigint(20) NOT NULL,
      PRIMARY KEY (`CD_ID`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1
    ;

    CREATE TABLE IF NOT EXISTS `COLUMNS_V2` (
      `CD_ID` bigint(20) NOT NULL,
      `COMMENT` varchar(256) CHARACTER SET latin1 COLLATE latin1_bin DEFAULT NULL,
      `COLUMN_NAME` varchar(128) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL,
      `TYPE_NAME` varchar(4000) DEFAULT NULL,
      `INTEGER_IDX` int(11) NOT NULL,
      PRIMARY KEY (`CD_ID`,`COLUMN_NAME`),
      KEY `COLUMNS_V2_N49` (`CD_ID`),
      CONSTRAINT `COLUMNS_V2_FK1` FOREIGN KEY (`CD_ID`) REFERENCES `CDS` (`CD_ID`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1
    ;
  END $$

/*
 * Procedures called before migration happens
 */ 
CREATE PROCEDURE PRE_MIGRATE()
  BEGIN
    call CREATE_TABLES();
    SELECT 'Created tables';
    call CREATE_TABLE_SDS();
    SELECT 'Created the temp table TABLE_SDS';
    call ALTER_SDS();
    SELECT 'Altered the SDS table';
  END $$

/*
 * Migrate the TBLS table
 * Add entries into CDS.
 * Populate the CD_ID field in SDS for tables
 * Add entires to COLUMNS_V2 based on this table's sd's columns
 */ 
CREATE PROCEDURE MIGRATE_TABLES()
  BEGIN
    /* In the migration, there is a 1:1 mapping between CD_ID and SD_ID
     * for tables. For speed, just let CD_ID = SD_ID for tables 
     */
    INSERT INTO CDS (CD_ID)
    SELECT SD_ID FROM TABLE_SDS;
    SELECT 'Inserted into CDS';
    
    UPDATE SDS
      SET CD_ID = SD_ID
    WHERE SD_ID in 
    (select SD_ID from TABLE_SDS);
    SELECT 'Updated CD_ID in SDS';

    INSERT INTO COLUMNS_V2
      (CD_ID, COMMENT, COLUMN_NAME, TYPE_NAME, INTEGER_IDX)
    SELECT 
      c.SD_ID, c.COMMENT, c.COLUMN_NAME, c.TYPE_NAME, c.INTEGER_IDX
    FROM
      COLUMNS c
    JOIN
      TBLS t
    ON
      t.SD_ID = c.SD_ID
    ;
    SELECT 'Inserted table columns into COLUMNS_V2';
  END $$

/*
 * Migrate the partitions.
 * Update the partition's SDS to use the parent table's CD_ID
 */
CREATE PROCEDURE MIGRATE_PARTITIONS()
  BEGIN
    UPDATE SDS sd
    JOIN PARTITIONS p on p.SD_ID = sd.SD_ID
    JOIN TBLS t on t.TBL_ID = p.TBL_ID
    SET sd.CD_ID = t.SD_ID
    where p.SD_ID is not null
    ;
    SELECT 'Updated CD_IDs in SDS for partitions'
      
  END $$

/*
 * Create a temp table that holds the SDS of tables
 */
CREATE PROCEDURE CREATE_TABLE_SDS()
  BEGIN
    CREATE TEMPORARY TABLE `TABLE_SDS` (
      `SD_ID` bigint(20) NOT NULL,
      PRIMARY KEY (`SD_ID`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1
    ;
    INSERT INTO TABLE_SDS 
      (SD_ID)
    SELECT
      t.SD_ID
    FROM
      TBLS t
    WHERE
      t.SD_ID IS NOT NULL
    ORDER BY 
      t.SD_ID
    ;
 END $$

/*
 * A currently unused function to igrate the COLUMNS_V2 table
 * to have the name COLUMNS
 */
CREATE PROCEDURE RENAME_TMP_COLUMNS()
  BEGIN
    /*DROP TABLE `COLUMNS`;*/
    RENAME TABLE `COLUMNS_V2` TO `COLUMNS`;
    SELECT 'Renamed COLUMNS_V2 to COLUMNS';
    ALTER TABLE `COLUMNS`
      DROP FOREIGN KEY `COLUMNS_V2_FK1`;
    SELECT 'Dropped FK on Columns';
    DROP INDEX `COLUMNS_V2_N49` ON COLUMNS;
    SELECT 'Dropped Index on Columns';
    CREATE INDEX `COLUMNS_N49` ON COLUMNS
      (CD_ID)
    ;
    SELECT 'Added index on Columns';
    ALTER TABLE COLUMNS_
    ADD CONSTRAINT `COLUMNS_FK1`
      FOREIGN KEY (`CD_ID`) REFERENCES `CDS` (`CD_ID`)
    ;
    SELECT 'Added FK on Columns';
  END $$

/*
 * Main call for migration
 */
CREATE PROCEDURE MIGRATE()
  BEGIN
    call PRE_MIGRATE();
    SELECT 'Completed pre migration';
    call MIGRATE_TABLES();
    SELECT 'Completed migrating tables';
    call MIGRATE_PARTITIONS();
    SELECT 'Completed migrating partitions';
    /* Migrate indexes? */
  END $$

DELIMITER ;
