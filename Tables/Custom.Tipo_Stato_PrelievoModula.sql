CREATE TABLE [Custom].[Tipo_Stato_PrelievoModula]
(
[Id_Tipo_Stato_PrelievoModula] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Descrizione_Abbreviata] [varchar] (3) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Stato_PrelievoModula] ADD CONSTRAINT [PK__Tipo_Sta__E70B41E5429BAFBA] PRIMARY KEY CLUSTERED ([Id_Tipo_Stato_PrelievoModula]) ON [PRIMARY]
GO
