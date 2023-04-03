CREATE TABLE [dbo].[Lista_Host_Gruppi]
(
[Id_Gruppo_Lista] [int] NOT NULL IDENTITY(1, 1),
[Descrizione] [varchar] (150) COLLATE Latin1_General_CI_AS NULL,
[Id_Utente_Elaborazione] [varchar] (16) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Partizione_Destinazione] [int] NOT NULL,
[Id_Stato_Gruppo] [int] NOT NULL,
[Id_Tipo_Gruppo] [varchar] (2) COLLATE Latin1_General_CI_AS NOT NULL,
[Priorita] [int] NULL,
[DockNumber] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lista_Host_Gruppi] ADD CONSTRAINT [PK_Lista_Host_Gruppi] PRIMARY KEY CLUSTERED ([Id_Gruppo_Lista]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Lista_Host_Gruppi] ADD CONSTRAINT [FK_Lista_Host_Gruppi_Partizioni] FOREIGN KEY ([Id_Partizione_Destinazione]) REFERENCES [dbo].[Partizioni] ([ID_PARTIZIONE])
GO
ALTER TABLE [dbo].[Lista_Host_Gruppi] ADD CONSTRAINT [FK_Lista_Host_Gruppi_Tipo_Lista] FOREIGN KEY ([Id_Tipo_Gruppo]) REFERENCES [dbo].[Tipo_Lista] ([Id_Tipo_Lista])
GO
ALTER TABLE [dbo].[Lista_Host_Gruppi] ADD CONSTRAINT [FK_Lista_Host_Gruppi_Tipo_Priorita] FOREIGN KEY ([Priorita]) REFERENCES [dbo].[Tipo_Priorita] ([Priorita])
GO
ALTER TABLE [dbo].[Lista_Host_Gruppi] ADD CONSTRAINT [FK_Lista_Host_Gruppi_Tipo_Stati_Lista] FOREIGN KEY ([Id_Stato_Gruppo]) REFERENCES [dbo].[Tipo_Stati_Lista] ([Id_Stato_Lista])
GO
