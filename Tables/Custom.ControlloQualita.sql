CREATE TABLE [Custom].[ControlloQualita]
(
[Id_UdcDettaglio] [int] NOT NULL,
[Quantita] [numeric] (10, 2) NOT NULL,
[MotivoQualita] [varchar] (max) COLLATE Latin1_General_CI_AS NULL,
[Doppio_Step_QM] [bit] NULL,
[CONTROL_LOT] [varchar] (40) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Utente] [varchar] (50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE TRIGGER [Custom].[AfterUpdateCq]
  ON [Custom].[ControlloQualita]
  AFTER UPDATE 
  AS
  BEGIN
		SET NOCOUNT ON;
		DECLARE @Qta numeric(10,2);
		DECLARE @Id_UdcDettaglio int


		SELECT @Id_UdcDettaglio = cq.Id_UdcDettaglio, @Qta = cq.Quantita FROM Custom.ControlloQualita cq
		INNER JOIN inserted on inserted.Id_UdcDettaglio = cq.Id_UdcDettaglio
		
		IF (@Qta = 0)
			DELETE FROM Custom.ControlloQualita WHERE Id_UdcDettaglio = @Id_UdcDettaglio
  END
GO
ALTER TABLE [Custom].[ControlloQualita] ADD CONSTRAINT [CK__Controllo__Quant__1D5142F3] CHECK (([Quantita]>=(0)))
GO
ALTER TABLE [Custom].[ControlloQualita] ADD CONSTRAINT [PK_ControlloQualita] PRIMARY KEY CLUSTERED ([Id_UdcDettaglio], [CONTROL_LOT]) ON [PRIMARY]
GO
ALTER TABLE [Custom].[ControlloQualita] ADD CONSTRAINT [FK__Controllo__Id_Ud__1E45672C] FOREIGN KEY ([Id_UdcDettaglio]) REFERENCES [dbo].[Udc_Dettaglio] ([Id_UdcDettaglio]) ON DELETE CASCADE
GO
