CREATE TABLE [Custom].[NonConformita]
(
[Id_UdcDettaglio] [int] NOT NULL,
[Quantita] [numeric] (10, 2) NOT NULL,
[MotivoNonConformita] [varchar] (max) COLLATE Latin1_General_CI_AS NULL,
[CONTROL_LOT] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/


  CREATE TRIGGER [Custom].[AfterUpdateNc]
  ON [Custom].[NonConformita]
  AFTER UPDATE 
  AS
  BEGIN
		SET NOCOUNT ON;
		DECLARE @Qta numeric(10,2);
		DECLARE @Id_UdcDettaglio int


		SELECT @Id_UdcDettaglio = nc.Id_UdcDettaglio, @Qta = NC.Quantita FROM Custom.NonConformita NC 
		INNER JOIN inserted on inserted.Id_UdcDettaglio = NC.Id_UdcDettaglio
		
		IF (@Qta = 0)
			DELETE FROM Custom.NonConformita WHERE Id_UdcDettaglio = @Id_UdcDettaglio
  END
GO
ALTER TABLE [Custom].[NonConformita] ADD CONSTRAINT [PK__NonConfr__A000DB88FE2FB42F] PRIMARY KEY CLUSTERED ([Id_UdcDettaglio], [CONTROL_LOT]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[NonConformita] ADD CONSTRAINT [FK__NonConfro__Id_Ud__1980B20F] FOREIGN KEY ([Id_UdcDettaglio]) REFERENCES [dbo].[Udc_Dettaglio] ([Id_UdcDettaglio]) ON DELETE CASCADE
GO
