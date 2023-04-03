CREATE TABLE [dbo].[Percorso_PreCalc]
(
[Id_Percorso] [int] NOT NULL IDENTITY(1, 1),
[Id_Partizione_Sorgente] [int] NOT NULL,
[Id_Partizione_Destinazione] [int] NOT NULL,
[Id_Tipo_Udc] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Steps] [xml] NULL,
[Itinerario] [xml] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Percorso_PreCalc] ADD CONSTRAINT [PK_Percorso_Precalc_Testata] PRIMARY KEY CLUSTERED ([Id_Percorso]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Percorso_PreCalc] ADD CONSTRAINT [FK_Percorso_Precalc_Testata_Tipo_Udc] FOREIGN KEY ([Id_Tipo_Udc]) REFERENCES [dbo].[Tipo_Udc] ([Id_Tipo_Udc])
GO
