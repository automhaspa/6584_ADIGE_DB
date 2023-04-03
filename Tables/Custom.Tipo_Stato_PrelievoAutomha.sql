CREATE TABLE [Custom].[Tipo_Stato_PrelievoAutomha]
(
[Id_Tipo_Stato_PrelievoAutomha] [int] NOT NULL,
[Descrizione] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Descrizione_Abbreviata] [varchar] (3) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Stato_PrelievoAutomha] ADD CONSTRAINT [PK__Tipo_Sta__00EF7949274F4BB3] PRIMARY KEY CLUSTERED ([Id_Tipo_Stato_PrelievoAutomha]) ON [PRIMARY]
GO
