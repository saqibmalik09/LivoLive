export type PeriodSalaryOverview = {
  periodId: string;
  bdMonth: string;
  hosts: {
    count: number;
    withProgress: number;
    estimatedUsd: number;
    paidUsd: number;
    paidRows: number;
  };
  agencies: {
    count: number;
    withLevel: number;
    estimatedUsd: number;
    paidUsd: number;
    paidRows: number;
  };
  bd: {
    count: number;
    withLevel: number;
    estimatedUsd: number;
    paidUsd: number;
    paidRows: number;
  };
  staff: {
    superBd: number;
    countyAdmin: number;
    bd: number;
  };
  grandEstimatedUsd: number;
  grandPaidUsd: number;
};
