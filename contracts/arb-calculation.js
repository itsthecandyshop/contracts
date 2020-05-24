async function calculateArbNum(token, tokenSold, isEthToToken) {
    let ethBalanceV1 = 0; // need to fetch this from contract
    let tokenBalaceV1 = 0; // need to fetch this from contract
    let ethBalanceV2 = 1; // need to fetch this from contract
    let tokenBalaceV2 = 200; // need to fetch this from contract

    let _x1 = isEthToToken ? ethBalanceV1 : tokenBalaceV1;
    let _y1 = isEthToToken ? tokenBalaceV1 : ethBalanceV1;
    let _x2 = isEthToToken ? ethBalanceV2 : tokenBalaceV2;
    let _y2 = isEthToToken ? tokenBalaceV2 : ethBalanceV2;

    let _sqrt = Math.sqrt(_x1 * _y1 * _x2 * _y2);
    let a = _y1 * _x2
    let b = _y1 + _y2

    arbNum = _sqrt - a;
    arbNum = arbNum / b;
    return arbNum
}