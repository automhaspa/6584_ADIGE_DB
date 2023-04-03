CREATE TABLE [Custom].[TipoStatoAnagrafica]
(
[ID] [int] NOT NULL,
[Descrizione] [varchar] (100) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[TipoStatoAnagrafica] ADD CONSTRAINT [PK__TipoStat__3214EC27EC49F4E8] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
