CREATE TABLE [Custom].[Tipo_Ordini_Prelievo]
(
[CODICE] [varchar] (5) COLLATE Latin1_General_CI_AS NOT NULL,
[DESCRIZIONE] [varchar] (25) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[Tipo_Ordini_Prelievo] ADD CONSTRAINT [PK_Custom_Tipo_Ordini_Prelievo] PRIMARY KEY CLUSTERED ([CODICE]) ON [PRIMARY]
GO
