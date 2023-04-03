CREATE TABLE [Custom].[AnagraficaDdtFittizi]
(
[ID] [int] NOT NULL IDENTITY(1, 1),
[Codice_DDT] [varchar] (11) COLLATE Latin1_General_CI_AS NULL,
[DataOra_Creazione] [datetime] NULL,
[N_Udc_Tipo_A] [int] NULL,
[N_Udc_Tipo_B] [int] NULL,
[N_Udc_Ingombranti] [int] NULL CONSTRAINT [DF_AnagraficaDdtFittizi_N_Udc_Ingombranti] DEFAULT ((0)),
[Id_Stato] [int] NULL CONSTRAINT [DF__Anagrafic__Id_St__72910220] DEFAULT ((1)),
[N_Udc_Ingombranti_M] [int] NULL
) ON [PRIMARY]
GO
ALTER TABLE [Custom].[AnagraficaDdtFittizi] ADD CONSTRAINT [PK__Anagrafi__3214EC27D5CD5DB7] PRIMARY KEY CLUSTERED ([ID]) ON [PRIMARY]
GO
