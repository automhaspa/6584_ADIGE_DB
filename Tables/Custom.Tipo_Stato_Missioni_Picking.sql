CREATE TABLE [Custom].[Tipo_Stato_Missioni_Picking]
(
[Id_Stato] [int] NOT NULL,
[Descrizione] [varchar] (20) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Stato_Missioni_Picking] ADD CONSTRAINT [PK__Tipo_Sta__3FDA21F180AF50CC] PRIMARY KEY CLUSTERED ([Id_Stato]) ON [PRIMARY]
GO
